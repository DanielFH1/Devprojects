import torch
import torch.nn as nn
import pandas as pd
import selfies as sf
from tqdm import tqdm
import math
import os
import numpy as np
import wandb  # 모니터링용

# --- 1. CONFIGURATION ---
CONFIG = {
    "project_name": "TransGEM_Exp3_ScaleUp",
    "experiment_name": "Mass_Generation_90k",
    "data_path": "./TransGEM/data/subLINCS.csv",
    "model_path": "checkpoints/model_epoch_200.pt", # 체크포인트 경로 확인!
    "output_dir": "experiment3_results",
    
    # Model Params
    "d_model": 64, "nhead": 8, "num_layers": 6, "ff_dim": 512, 
    "max_len": 100, "gene_dim": 978 * 10,
    
    # Experiment Params
    "target_cells": ["PC3", "A549", "MCF7"], # 전립선암, 폐암, 유방암
    "temperatures": [0.8, 1.0, 1.2],         # 다양성 조절 (낮을수록 보수적, 높을수록 창의적)
    "samples_per_condition": 10000,          # 조건당 10,000개
    "batch_size": 100                        # 한 번에 100개씩 생성 (속도 향상)
}

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# --- 2. MODEL CLASSES (Standalone) ---
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
        sz = tgt.size(1)
        mask = torch.triu(torch.ones(sz, sz) * float('-inf'), diagonal=1).to(tgt.device)
        output = self.transformer_decoder(tgt=tgt_embed, memory=memory, tgt_mask=mask)
        return self.generator(output)

# --- 3. HELPER FUNCTIONS ---
def build_vocab(smiles_list):
    vocab = set()
    print("Building Vocabulary...")
    for smiles in tqdm(smiles_list, desc="Tokenizing"):
        try:
            selfie = sf.encoder(smiles)
            if selfie is None: continue
            tokens = list(sf.split_selfies(selfie))
            vocab.update(tokens)
        except: continue
    vocab = sorted(list(vocab))
    token2idx = {'<pad>': 0, '<sos>': 1, '<eos>': 2}
    for i, token in enumerate(vocab): token2idx[token] = i + 3
    return token2idx

def parse_gene_string(gene_str):
    if isinstance(gene_str, str):
        try: return [float(x) for x in gene_str.split('//') if x.strip()]
        except: return []
    return []

def tenfold_binary_embedding(value):
    try: value = float(value)
    except: value = 0.0
    sign_bit = 1 if value > 0 else 0
    tenfold_value = int(abs(value) * 10)
    binary_str = bin(tenfold_value)[2:].zfill(9)
    if len(binary_str) > 9: binary_str = binary_str[-9:] 
    return [sign_bit] + [int(b) for b in binary_str]

# --- 4. MAIN EXECUTION ---
def main():
    # WandB Init
    wandb.init(project=CONFIG['project_name'], name=CONFIG['experiment_name'], config=CONFIG)
    
    if not os.path.exists(CONFIG['output_dir']):
        os.makedirs(CONFIG['output_dir'])

    print(f"🚀 Starting Scale-Up Experiment on {DEVICE}")
    print(f"🎯 Targets: {CONFIG['target_cells']}")
    print(f"🌡️ Temperatures: {CONFIG['temperatures']}")
    print(f"📦 Total Molecules to Generate: {len(CONFIG['target_cells']) * len(CONFIG['temperatures']) * CONFIG['samples_per_condition']}")

    # 1. Load Data & Vocab
    df = pd.read_csv(CONFIG['data_path'])
    token2idx = build_vocab(df['smiles'].tolist())
    idx2token = {v: k for k, v in token2idx.items()}
    
    cell_lines = sorted(df['cell_line'].unique().tolist())
    cell2idx = {name: i for i, name in enumerate(cell_lines)}
    
    # 2. Load Model
    model = TransGEM(
        num_genes_dim=CONFIG['gene_dim'], num_cells=len(cell_lines), vocab_size=len(token2idx),
        d_model=CONFIG['d_model'], nhead=CONFIG['nhead'], num_layers=CONFIG['num_layers'], dim_feedforward=CONFIG['ff_dim']
    ).to(DEVICE)
    
    if os.path.exists(CONFIG['model_path']):
        model.load_state_dict(torch.load(CONFIG['model_path']))
        print("✅ Model Checkpoint Loaded")
    else:
        raise FileNotFoundError(f"Model not found at {CONFIG['model_path']}")
    
    model.eval()

    # 3. Big Loop (Disease -> Temperature)
    total_generated = 0
    
    for disease in CONFIG['target_cells']:
        # Get Gene Data for this disease
        try:
            target_row = df[df['cell_line'] == disease].iloc[0]
        except:
            print(f"⚠️ Skipping {disease} (Not found in data)")
            continue
            
        raw_gene = target_row['gene_e']
        gene_values = parse_gene_string(raw_gene)
        gene_embeds = []
        for val in gene_values: gene_embeds.extend(tenfold_binary_embedding(val))
        
        # Padding
        if len(gene_embeds) != CONFIG['gene_dim']:
            gene_embeds = [0] * CONFIG['gene_dim']
            
        # Prepare Tensors (Single sample)
        gene_tensor_single = torch.tensor(gene_embeds, dtype=torch.float32).unsqueeze(0).to(DEVICE)
        cell_idx_single = torch.tensor([cell2idx[disease]], dtype=torch.long).to(DEVICE)
        
        for temp in CONFIG['temperatures']:
            output_filename = f"{CONFIG['output_dir']}/gen_{disease}_temp{temp}.txt"
            print(f"\n⚗️  Generating: {disease} @ Temp {temp} ...")
            
            generated_smiles_list = []
            num_batches = CONFIG['samples_per_condition'] // CONFIG['batch_size']
            
            # Batch Generation Loop
            for _ in tqdm(range(num_batches), desc=f"{disease}-T{temp}"):
                batch_size = CONFIG['batch_size']
                
                # Expand tensors to batch size
                gene_batch = gene_tensor_single.repeat(batch_size, 1)
                cell_batch = cell_idx_single.repeat(batch_size)
                curr_seq = torch.tensor([[token2idx['<sos>']]] * batch_size, dtype=torch.long).to(DEVICE)
                
                with torch.no_grad():
                    for _ in range(100): # Max Length
                        output = model(cell_batch, gene_batch, curr_seq)
                        next_token_logits = output[:, -1, :]
                        
                        # Temperature Sampling
                        probs = torch.nn.functional.softmax(next_token_logits / temp, dim=-1)
                        next_token = torch.multinomial(probs, 1)
                        
                        curr_seq = torch.cat([curr_seq, next_token], dim=1)
                
                # Decoding Batch
                indices_list = curr_seq.cpu().numpy()
                for indices in indices_list:
                    tokens = []
                    for idx in indices:
                        if idx == token2idx['<eos>']: break
                        if idx not in [token2idx['<sos>'], token2idx['<pad>']]:
                            tokens.append(idx2token[idx])
                    try:
                        smiles = sf.decoder("".join(tokens))
                        if smiles: generated_smiles_list.append(smiles)
                    except: continue
                
                # WandB Logging (실시간 그래프용)
                total_generated += batch_size
                wandb.log({"total_generated": total_generated, "current_disease": disease})
            
            # Save to File
            with open(output_filename, "w") as f:
                for s in generated_smiles_list:
                    f.write(s + "\n")
            print(f"💾 Saved {len(generated_smiles_list)} molecules to {output_filename}")

    print("🎉 All Generations Complete!")
    wandb.finish()

if __name__ == "__main__":
    main()