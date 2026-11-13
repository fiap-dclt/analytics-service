# ==========================================
# Stage 1: Build das dependências Python
# ==========================================
# Utiliza Python 3.13 e Debian 13, compatíveis com a imagem Distroless final.
FROM python:3.13-slim-trixie AS builder

WORKDIR /app

# Isola as bibliotecas da aplicação em um ambiente virtual.
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Compilador somente no estágio de build; não será copiado para a imagem final.
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Instala as dependências da aplicação.
RUN pip install --no-cache-dir -r requirements.txt

# Mantém o setuptools disponível para dependências que
# possam utilizá-lo em tempo de execução.
# Atualiza bibliotecas internas para corrigir vulnerabilidades.
RUN pip install --no-cache-dir --upgrade setuptools==80.10.2

# Verifica a consistência das dependências instaladas.
RUN pip check

# Valida a importação das principais bibliotecas da aplicação.
RUN python -c "import flask, gunicorn, boto3, dotenv, setuptools; print('Dependencies OK')"

# ==========================================
# Stage 2: Imagem final Distroless
# ==========================================
# Debian 13 é a linha de imagens Python Distroless suportada atualmente.
FROM gcr.io/distroless/python3-debian13:nonroot

WORKDIR /app

# O Python da imagem final é 3.13; exponha o site-packages do ambiente virtual.
COPY --from=builder --chown=nonroot:nonroot /opt/venv /opt/venv
ENV PYTHONPATH="/opt/venv/lib/python3.13/site-packages"
ENV PATH="/opt/venv/bin:$PATH"

COPY --chown=nonroot:nonroot app.py .

USER nonroot
EXPOSE 8005

# Inicia o Gunicorn com o Python da imagem final. Isso evita depender de um
# shebang do ambiente virtual que possa apontar para o Python do builder.
ENTRYPOINT ["/usr/bin/python", "-m", "gunicorn"]
CMD ["--bind", "0.0.0.0:8005", "app:app"]
