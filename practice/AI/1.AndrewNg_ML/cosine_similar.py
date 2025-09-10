import gensim.downloader as api
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np

# Word2Vec 모델 불러오기
model = api.load("glove-wiki-gigaword-50")

#문장벡터 계산
def sentence_to_vector(sentence, model):
    words = sentence.lower().split()
    word_vectors = []

    for word in words:
        if word in model:
            word_vectors.append(model[word])
    if len(word_vectors) == 0:
        return np.zeros(model.vector_size)
    return np.mean(word_vectors, axis=0)

#코사인 유사도 계산
def cosine_similarity_sentence(sentence1, sentence2, model):
    vec1 = sentence_to_vector(sentence1,model)
    vec2 = sentence_to_vector(sentence2,model)
    return cosine_similarity([vec1],[vec2])[0][0]

#예제
sentence1 = "I love food"
sentence2 = "I enjoy eating"

#유사도 계산
similarity = cosine_similarity_sentence(sentence1, sentence2, model)
print(f"Cosine similarity : {similarity:.4f}")