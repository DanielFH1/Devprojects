import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import pandas as pd
import numpy as np
import selfies as sf
from tqdm import tqdm
import math
import wandb
import os
import json

# --- Configuration ---
CONFIG = {
    "project_name": "TransGEM_Reproduction",
    "experiment_name": "Exp1_Baseline_FullData",
    "data_path": "./TransGEM/data/subLINCS.csv",
    "batch_size": 4,          # 논문 설정 [cite: 255]
    "epochs": 200,            # 논문 설정 [cite: 255]
    "lr": 0.0001,             # 논문 설정 [cite: 255]
    "d_model": 64,            # 논문 설정 [cite: 255]
    "nhead": 8,               # 논문 설정 [cite: 255]
    "num_layers": 6,          # 논문 설정 [cite: 255]
    "ff_dim": 512,            # 논문 설정 [cite: 255]
    "max_len": 100,
    "gene_dim": 978 * 10      # 978 genes * 10-bit embedding [cite: 178]
}

# --- 1. Utils: Tokenizer ---
def build_vocab(smiles_list):
    vocab = set()
    print("Building Vocabulary...")
    for smiles in tqdm(smiles_list, desc="Tokenizing"):
        try:
            selfie = sf.encoder(smiles)
            if selfie is None: continue
            tokens = list(sf.split_selfies(selfie))
            vocab.update(tokens)
        except:
            continue
            
    vocab = sorted(list(vocab))
    token2idx = {'<pad>': 0, '<sos>': 1, '<eos>': 2}
    for i, token in enumerate(vocab):
        token2idx[token] = i + 3
    return token2idx

def smile_to_indices(smiles, token2idx, max_len):
    try:
        selfie = sf.encoder(smiles)
        tokens = list(sf.split_selfies(selfie))
        indices = [token2idx['<sos>']] + [token2idx.get(t, token2idx['<pad>']) for t in tokens] + [token2idx['<eos>']]
        if len(indices) < max_len:
            indices += [token2idx['<pad>']] * (max_len - len(indices))
        else:
            indices = indices[:max_len]
        return indices
    except:
        return [token2idx['<pad>']] * max_len

# --- 2. Dataset Class (Corrected) ---
class TransGEMDataset(Dataset):
    def __init__(self, df, token2idx, max_len):
        self.df = df.reset_index(drop=True)
        self.token2idx = token2idx
        self.max_len = max_len
        
        self.cell_lines = sorted(df['cell_line'].unique().tolist())
        self.cell2idx = {name: i for i, name in enumerate(self.cell_lines)}
        
        if 'gene_e' in df.columns:
            self.gene_col_name = 'gene_e'
            print(f"✅ 'gene_e' column detected. Parsing 'sep=//' format.")
        else:
            raise ValueError("Could not find 'gene_e' column!")
            
    def __len__(self):
        return len(self.df)
    
    def tenfold_binary_embedding(self, value):
        try:
            value = float(value)
        except:
            value = 0.0
        sign_bit = 1 if value > 0 else 0
        tenfold_value = int(abs(value) * 10)
        binary_str = bin(tenfold_value)[2:].zfill(9)
        if len(binary_str) > 9: binary_str = binary_str[-9:] 
        return [sign_bit] + [int(b) for b in binary_str]

    def parse_gene_string(self, gene_str):
        if isinstance(gene_str, str):
            try:
                return [float(x) for x in gene_str.split('//') if x.strip()]
            except:
                return []
        return []

    def __getitem__(self, idx):
        row = self.df.iloc[idx]
        cell_idx = self.cell2idx.get(row['cell_line'], 0)
        
        raw_gene_data = row[self.gene_col_name]
        gene_values = self.parse_gene_string(raw_gene_data)
            
        gene_embeds = []
        for val in gene_values:
            gene_embeds.extend(self.tenfold_binary_embedding(val))
            
        # 만약 파싱 실패 등으로 길이가 안 맞으면 0으로 채움 (안전장치)
        expected_len = 978 * 10
        if len(gene_embeds) != expected_len:
            gene_embeds = [0] * expected_len
            
        return {
            'cell_idx': torch.tensor(cell_idx, dtype=torch.long),
            'gene_tensor': torch.tensor(gene_embeds, dtype=torch.float32), 
            'target': torch.tensor(smile_to_indices(row['smiles'], self.token2idx, self.max_len), dtype=torch.long)
        }

# --- 3. Model Architecture ---
class PositionalEncoding(nn.Module):
    def __init__(self, d_model, dropout=0.1, max_len=500):
        super(PositionalEncoding, self).__init__()
        self.dropout = nn.Dropout(p=dropout)
        pe = torch.zeros(max_len, d_model)
        position = torch.arange(0, max_len, dtype=torch.float).unsqueeze(1)
        div_term = torch.exp(torch.arange(0, d_model, 2).float() * (-math.log(10000.0) / d_model))
        pe[:, 0::2] = torch.sin(position * div_term)
        pe[:, 1::2] = torch.cos(position * div_term)
        self.register_buffer('pe', pe.unsqueeze(0))
    def forward(self, x):
        x = x + self.pe[:, :x.size(1)]
        return self.dropout(x)

class TransGEM(nn.Module):
    def __init__(self, num_genes_dim, num_cells, vocab_size, d_model=64, nhead=8, num_layers=6, dim_feedforward=512):
        super(TransGEM, self).__init__()
        self.d_model = d_model
        self.cell_embedding = nn.Embedding(num_cells, d_model)
        self.gene_linear = nn.Sequential(
            nn.Linear(num_genes_dim, d_model), nn.ReLU(), nn.Linear(d_model, d_model)
        )
        self.fusion_layer = nn.Sequential(
            nn.Linear(d_model * 2, d_model), nn.ReLU(), nn.Linear(d_model, d_model)
        )
        self.mol_embedding = nn.Embedding(vocab_size, d_model)
        self.pos_encoder = PositionalEncoding(d_model)
        decoder_layer = nn.TransformerDecoderLayer(d_model=d_model, nhead=nhead, dim_feedforward=dim_feedforward, batch_first=True)
        self.transformer_decoder = nn.TransformerDecoder(decoder_layer, num_layers=num_layers)
        self.generator = nn.Linear(d_model, vocab_size)

    def forward(self, cell_idx, gene_tensor, tgt):
        cell_embed = self.cell_embedding(cell_idx)
        gene_embed = self.gene_linear(gene_tensor)
        context = torch.cat([cell_embed, gene_embed], dim=-1)
        memory = self.fusion_layer(context).unsqueeze(1)
        
        tgt_embed = self.mol_embedding(tgt) * math.sqrt(self.d_model)
        tgt_embed = self.pos_encoder(tgt_embed)
        
        # Causal Mask (현재보다 미래의 토큰을 보지 못하게)
        sz = tgt.size(1)
        mask = torch.triu(torch.ones(sz, sz) * float('-inf'), diagonal=1).to(tgt.device)
        
        output = self.transformer_decoder(tgt=tgt_embed, memory=memory, tgt_mask=mask)
        return self.generator(output)

# --- 4. Training Loop ---
def main():
    # Setup
    DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    wandb.init(project=CONFIG['project_name'], name=CONFIG['experiment_name'], config=CONFIG)
    
    if not os.path.exists('checkpoints'): os.makedirs('checkpoints')

    # Load Data
    print("Loading Data...")
    df = pd.read_csv(CONFIG['data_path'])
    token2idx = build_vocab(df['smiles'].tolist())
    dataset = TransGEMDataset(df, token2idx, max_len=CONFIG['max_len'])
    dataloader = DataLoader(dataset, batch_size=CONFIG['batch_size'], shuffle=True, num_workers=4)

    # Model
    model = TransGEM(
        num_genes_dim=CONFIG['gene_dim'],
        num_cells=len(dataset.cell_lines),
        vocab_size=len(token2idx),
        d_model=CONFIG['d_model'], nhead=CONFIG['nhead'], num_layers=CONFIG['num_layers'], dim_feedforward=CONFIG['ff_dim']
    ).to(DEVICE)
    
    optimizer = optim.Adam(model.parameters(), lr=CONFIG['lr'])
    criterion = nn.CrossEntropyLoss(ignore_index=token2idx['<pad>'])
    
    print(f"🚀 Training Start! Total Epochs: {CONFIG['epochs']}")
    
    for epoch in range(CONFIG['epochs']):
        model.train()
        total_loss = 0
        
        progress_bar = tqdm(dataloader, desc=f"Epoch {epoch+1}/{CONFIG['epochs']}")
        for batch in progress_bar:
            cell_idx = batch['cell_idx'].to(DEVICE)
            gene_tensor = batch['gene_tensor'].to(DEVICE)
            target = batch['target'].to(DEVICE)

            tgt_input = target[:, :-1] # <sos> ...
            tgt_output = target[:, 1:] # ... <eos>

            optimizer.zero_grad()
            output = model(cell_idx, gene_tensor, tgt_input)
            
            # Reshape for Loss
            loss = criterion(output.reshape(-1, output.shape[-1]), tgt_output.reshape(-1))
            loss.backward()
            optimizer.step()
            
            total_loss += loss.item()
            progress_bar.set_postfix(loss=loss.item())
            
        avg_loss = total_loss / len(dataloader)
        print(f"Epoch {epoch+1} Avg Loss: {avg_loss:.4f}")
        
        # WandB Logging [cite: 133]
        wandb.log({"train_loss": avg_loss, "epoch": epoch+1})
        
        # Save Checkpoint every 10 epochs
        if (epoch + 1) % 10 == 0:
            torch.save(model.state_dict(), f"checkpoints/model_epoch_{epoch+1}.pt")
            
    print("✅ Training Finished!")
    wandb.finish()

if __name__ == "__main__":
    main()