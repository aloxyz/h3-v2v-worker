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
    uv pip install -r requirements.txt

# Bug osservato nella build: dopo l'install sopra manca il file
# comfy_aimdo/malloc_graph.py (tutti gli altri file del pacchetto, inclusi i
# moduli nativi .so, ci sono). La wheel su PyPI contiene di sicuro quel file
# (verificato scaricandola e ispezionandola a parte) e "uv pip install
# --force-reinstall" dalla stessa URL dà lo stesso risultato incompleto —
# sembra una cache di uv corrotta/incompleta che force-reinstall non invalida.
# Bypassiamo del tutto uv per questo pacchetto: scarichiamo la wheel e la
# scompattiamo noi stessi con zipfile, senza passare da nessuna cache.
RUN python3 -c "\
import urllib.request, zipfile, io, site, os; \
url = 'https://files.pythonhosted.org/packages/1a/bc/aa38d79aed78aee21d1186e056f8b8e348c6af78874d6f7ed257a6dddf5d/comfy_aimdo-0.5.3-cp39-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.whl'; \
data = urllib.request.urlopen(url).read(); \
target = site.getsitepackages()[0]; \
zipfile.ZipFile(io.BytesIO(data)).extractall(target); \
print('estratti', len(data), 'byte in', target); \
print(sorted(os.listdir(os.path.join(target, 'comfy_aimdo'))))"

# Diagnostica temporanea: conferma che ora malloc_graph.py c'è davvero e che
# l'import funziona, prima di rimuovere questo passaggio.
RUN python3 -c "\
import comfy_aimdo, os; \
print('comfy_aimdo.__path__:', list(comfy_aimdo.__path__)); \
[print(p, '->', sorted(os.listdir(p)) if os.path.isdir(p) else 'MANCA') for p in comfy_aimdo.__path__]; \
import comfy_aimdo.malloc_graph; \
print('import comfy_aimdo.malloc_graph OK')"

# extra_model_paths.yaml personalizzato: aggiunge model_patches/ (dove sta il
# Fun ControlNet di H3) alle cartelle già mappate dal Network Volume — quello
# di default del worker non lo include.
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# Verifica di build: avvia ComfyUI (importa l'intero grafo dei nodi) così una
# dipendenza rotta fa fallire QUI la build, non in un worker già in produzione.
RUN cd /comfyui && timeout 300 python main.py --quick-test-for-ci --cpu
