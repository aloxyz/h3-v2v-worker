FROM docker.io/runpod/worker-comfyui:5.10.0-base-cuda12.8.1

ARG COMFYUI_VERSION=0.36.0

# Aggiorna ComfyUI alla versione richiesta e le sue dipendenze Python.
RUN cd /comfyui && \
    git fetch --depth 1 origin tag v${COMFYUI_VERSION} && \
    git checkout -f v${COMFYUI_VERSION} && \
    uv pip install -r requirements.txt

# extra_model_paths.yaml personalizzato: aggiunge model_patches/ (dove sta il
# Fun ControlNet di H3) alle cartelle già mappate dal Network Volume — quello
# di default del worker non lo include.
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# Verifica di build: avvia ComfyUI (importa l'intero grafo dei nodi) così una
# dipendenza rotta fa fallire QUI la build, non in un worker già in produzione.
RUN cd /comfyui && timeout 300 python main.py --quick-test-for-ci --cpu
