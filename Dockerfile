# Immagine worker-comfyui con ComfyUI aggiornato (>= 0.35) per supportare il nodo
# MiniMaxH3FunControlNetApply, necessario per il V2V di MiniMax H3 (copia del
# movimento da un video / modifica con maschera). L'immagine ufficiale
# runpod/worker-comfyui:5.10.0 ha ComfyUI 0.34.0, troppo vecchia per quel nodo
# (aggiunto in ComfyUI 0.35, 31 agosto 2026).
FROM docker.io/runpod/worker-comfyui:5.10.0-base-cuda12.8.1

ARG COMFYUI_VERSION=0.36.0

# Aggiorna ComfyUI alla versione richiesta e le sue dipendenze Python.
RUN cd /comfyui && \
    git fetch --depth 1 origin tag v${COMFYUI_VERSION} && \
    git checkout -f v${COMFYUI_VERSION} && \
    uv pip install -r requirements.txt && \
    # Bug osservato nella build: per comfy-aimdo (pacchetto con moduli nativi
    # compilati, es. malloc_graph) uv a volte risolve la wheel "py3-none-any"
    # (uno stub senza i moduli compilati) invece di quella per questa
    # piattaforma — forziamo esplicitamente la wheel Linux x86_64 corretta.
    uv pip install --force-reinstall --no-deps \
      "https://files.pythonhosted.org/packages/1a/bc/aa38d79aed78aee21d1186e056f8b8e348c6af78874d6f7ed257a6dddf5d/comfy_aimdo-0.5.3-cp39-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.whl"

# extra_model_paths.yaml personalizzato: aggiunge model_patches/ (dove sta il
# Fun ControlNet di H3) alle cartelle già mappate dal Network Volume — quello
# di default del worker non lo include.
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# Verifica di build: avvia ComfyUI (importa l'intero grafo dei nodi) così una
# dipendenza rotta fa fallire QUI la build, non in un worker già in produzione.
RUN cd /comfyui && timeout 300 python main.py --quick-test-for-ci --cpu
