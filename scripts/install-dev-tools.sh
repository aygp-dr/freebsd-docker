#!/bin/sh
# Install modern development tools including AI CLI tools
# This script runs INSIDE the FreeBSD VM after initial setup

set -e

echo "Installing additional development tools..."

# Ensure npm is available
if ! command -v npm >/dev/null 2>&1; then
    echo "Installing npm..."
    pkg install -y npm-node22
fi

# Create tools directory
mkdir -p /usr/local/dev-tools
cd /usr/local/dev-tools

# ===== AI Development Tools =====
echo "Installing AI development tools..."

# Claude Code (if available via npm)
echo "Checking for Claude Code CLI..."
npm list -g @anthropic/claude-code 2>/dev/null || npm install -g @anthropic/claude-code || echo "Claude Code CLI not available via npm yet"

# Gemini CLI
echo "Installing Gemini CLI..."
npm install -g @google/generative-ai-cli || echo "Gemini CLI package name may differ"

# OpenAI CLI tools
npm install -g openai-cli || true

# GitHub Copilot CLI
npm install -g @githubnext/github-copilot-cli || true

# ===== Core NPM Development Tools =====
echo "Installing core NPM development tools..."

npm install -g \
    typescript \
    ts-node \
    nodemon \
    pm2 \
    prettier \
    eslint \
    webpack \
    vite \
    parcel \
    turbo \
    nx \
    lerna \
    changesets \
    npm-check-updates \
    npkill \
    serve \
    http-server \
    json-server \
    concurrently \
    wait-on \
    cross-env \
    dotenv-cli \
    husky \
    lint-staged \
    commitizen \
    semantic-release \
    standard-version \
    release-it \
    plop \
    yeoman-generator \
    yo \
    create-react-app \
    create-next-app \
    @angular/cli \
    @vue/cli \
    @nestjs/cli \
    gatsby-cli \
    @11ty/eleventy \
    @remix-run/dev \
    astro \
    verdaccio \
    || true

# ===== Python Development Tools =====
echo "Installing Python development tools..."

pip install --upgrade pip
pip install \
    pipx \
    poetry \
    pipenv \
    black \
    flake8 \
    mypy \
    pylint \
    pytest \
    tox \
    pre-commit \
    cookiecutter \
    jupyterlab \
    ipython \
    pandas \
    numpy \
    matplotlib \
    requests \
    httpx \
    fastapi \
    django \
    flask \
    sqlalchemy \
    alembic \
    celery \
    ruff \
    uv \
    hatch \
    || true

# Install via pipx for isolation
pipx install \
    pdm \
    pyenv \
    virtualfish \
    pgcli \
    mycli \
    litecli \
    iredis \
    http-prompt \
    httpie \
    glances \
    || true

# ===== Ruby Development Tools =====
echo "Installing Ruby development tools..."

gem install \
    bundler \
    rake \
    rails \
    sinatra \
    pry \
    rubocop \
    solargraph \
    rspec \
    minitest \
    capistrano \
    foreman \
    tmuxinator \
    || true

# ===== Rust Development Tools =====
echo "Installing additional Rust tools..."

cargo install --locked \
    cargo-watch \
    cargo-edit \
    cargo-outdated \
    cargo-audit \
    cargo-generate \
    cargo-make \
    cross \
    wasm-pack \
    trunk \
    mdbook \
    mdbook-mermaid \
    zellij \
    helix \
    || true

# ===== Go Development Tools =====
echo "Installing Go development tools..."

go install github.com/cosmtrek/air@latest || true
go install github.com/go-delve/delve/cmd/dlv@latest || true
go install golang.org/x/tools/gopls@latest || true
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest || true
go install github.com/goreleaser/goreleaser@latest || true
go install github.com/golang-migrate/migrate/v4/cmd/migrate@latest || true

# ===== Cloud Provider CLIs =====
echo "Installing cloud provider CLIs..."

# AWS CLI
pip install awscli awsebcli aws-sam-cli || true

# Google Cloud SDK
cd /tmp
fetch https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-freebsd-x86_64.tar.gz
tar xzf google-cloud-cli-freebsd-x86_64.tar.gz -C /usr/local/
/usr/local/google-cloud-sdk/install.sh --quiet
ln -s /usr/local/google-cloud-sdk/bin/gcloud /usr/local/bin/
ln -s /usr/local/google-cloud-sdk/bin/gsutil /usr/local/bin/
cd -

# Azure CLI
pip install azure-cli || true

# DigitalOcean CLI
cd /tmp
fetch https://github.com/digitalocean/doctl/releases/latest/download/doctl-freebsd-amd64.tar.gz
tar xf doctl-freebsd-amd64.tar.gz
mv doctl /usr/local/bin/
cd -

# Linode CLI
pip install linode-cli || true

# Oracle Cloud CLI
pip install oci-cli || true

# ===== Container & Orchestration Tools =====
echo "Installing container and orchestration tools..."

# Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl /usr/local/bin/

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# K9s
curl -L https://github.com/derailed/k9s/releases/latest/download/k9s_FreeBSD_amd64.tar.gz | tar xz -C /usr/local/bin/

# Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-freebsd-amd64
chmod +x ./kind && mv ./kind /usr/local/bin/

# Skaffold
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-freebsd-amd64
chmod +x skaffold && mv skaffold /usr/local/bin/

# Kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
mv kustomize /usr/local/bin/

# ArgoCD CLI
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-freebsd-amd64
chmod +x /usr/local/bin/argocd

# Flux CLI
curl -s https://fluxcd.io/install.sh | bash

# ===== Infrastructure as Code Tools =====
echo "Installing IaC tools..."

# Pulumi
curl -fsSL https://get.pulumi.com | sh
ln -s ~/.pulumi/bin/pulumi /usr/local/bin/

# Crossplane CLI
curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | sh
mv kubectl-crossplane /usr/local/bin/

# Terragrunt
fetch https://github.com/gruntwork-io/terragrunt/releases/latest/download/terragrunt_freebsd_amd64
chmod +x terragrunt_freebsd_amd64
mv terragrunt_freebsd_amd64 /usr/local/bin/terragrunt

# Cloud Development Kit
npm install -g aws-cdk
npm install -g cdktf-cli

# ===== Service Mesh & API Gateway Tools =====
echo "Installing service mesh tools..."

# Istio CLI
curl -L https://istio.io/downloadIstio | sh -
ln -s /usr/local/istio-*/bin/istioctl /usr/local/bin/

# Linkerd CLI
curl -sL https://run.linkerd.io/install | sh
ln -s ~/.linkerd2/bin/linkerd /usr/local/bin/

# Consul
fetch https://releases.hashicorp.com/consul/1.17.0/consul_1.17.0_freebsd_amd64.zip
unzip consul_1.17.0_freebsd_amd64.zip
mv consul /usr/local/bin/
rm consul_1.17.0_freebsd_amd64.zip

# ===== Monitoring & Observability Tools =====
echo "Installing monitoring tools..."

# Prometheus CLI tools
go install github.com/prometheus/prometheus/cmd/promtool@latest || true

# Grafana CLI
go install github.com/grafana/grafana/pkg/cmd/grafana-cli@latest || true

# Jaeger CLI
fetch https://github.com/jaegertracing/jaeger/releases/latest/download/jaeger-freebsd-amd64.tar.gz
tar xzf jaeger-freebsd-amd64.tar.gz
mv jaeger-*/jaeger /usr/local/bin/

# ===== Security & Compliance Tools =====
echo "Installing security tools..."

# Trivy
fetch https://github.com/aquasecurity/trivy/releases/latest/download/trivy_FreeBSD-64bit.tar.gz
tar xzf trivy_FreeBSD-64bit.tar.gz
mv trivy /usr/local/bin/

# Kubesec
curl -sSL https://github.com/controlplaneio/kubesec/releases/latest/download/kubesec_freebsd_amd64.tar.gz | tar xz
mv kubesec /usr/local/bin/

# SOPS
fetch https://github.com/mozilla/sops/releases/latest/download/sops-freebsd
chmod +x sops-freebsd
mv sops-freebsd /usr/local/bin/sops

# ===== Database Tools =====
echo "Installing database tools..."

# Install database migration tools
npm install -g \
    prisma \
    typeorm \
    knex \
    sequelize-cli \
    || true

# ===== Documentation Tools =====
echo "Installing documentation tools..."

npm install -g \
    @redocly/cli \
    @apidevtools/swagger-cli \
    spectacle-docs \
    jsdoc \
    typedoc \
    || true

# ===== Testing Tools =====
echo "Installing testing tools..."

npm install -g \
    jest \
    mocha \
    ava \
    tap \
    playwright \
    cypress \
    puppeteer \
    || true

# ===== Create helper script for AI tools =====
cat > /usr/local/bin/ai-tools <<'EOF'
#!/bin/sh
# AI Development Tools Helper

case "$1" in
    claude)
        shift
        # Check if Claude Code is available
        if command -v claude >/dev/null 2>&1; then
            claude "$@"
        else
            echo "Claude Code CLI not installed. Visit: https://claude.ai/code"
            echo "Or try: npm install -g @anthropic/claude-code"
        fi
        ;;
    gemini)
        shift
        # Check if Gemini CLI is available
        if command -v gemini >/dev/null 2>&1; then
            gemini "$@"
        else
            echo "Gemini CLI not installed."
            echo "Try: npm install -g @google/generative-ai-cli"
        fi
        ;;
    copilot)
        shift
        if command -v github-copilot-cli >/dev/null 2>&1; then
            github-copilot-cli "$@"
        else
            echo "GitHub Copilot CLI not installed."
            echo "Try: npm install -g @githubnext/github-copilot-cli"
        fi
        ;;
    list)
        echo "Available AI tools:"
        command -v claude >/dev/null 2>&1 && echo "  ✓ claude - Claude Code CLI"
        command -v gemini >/dev/null 2>&1 && echo "  ✓ gemini - Gemini CLI"
        command -v github-copilot-cli >/dev/null 2>&1 && echo "  ✓ copilot - GitHub Copilot CLI"
        command -v openai >/dev/null 2>&1 && echo "  ✓ openai - OpenAI CLI"
        ;;
    install)
        echo "Installing all available AI CLI tools..."
        npm install -g @anthropic/claude-code || true
        npm install -g @google/generative-ai-cli || true
        npm install -g @githubnext/github-copilot-cli || true
        npm install -g openai-cli || true
        ;;
    *)
        echo "AI Development Tools Helper"
        echo ""
        echo "Usage: ai-tools <command> [options]"
        echo ""
        echo "Commands:"
        echo "  claude    - Run Claude Code CLI"
        echo "  gemini    - Run Gemini CLI"
        echo "  copilot   - Run GitHub Copilot CLI"
        echo "  list      - List installed AI tools"
        echo "  install   - Install all AI CLI tools"
        echo ""
        ;;
esac
EOF
chmod +x /usr/local/bin/ai-tools

# ===== Create development environment validation =====
cat > /usr/local/bin/validate-dev-env <<'EOF'
#!/bin/sh
echo "Development Environment Validation"
echo "==================================="
echo ""

# Check programming languages
echo "Programming Languages:"
for lang in node npm python3 ruby go rustc java clojure; do
    if command -v $lang >/dev/null 2>&1; then
        version=$($lang --version 2>&1 | head -n1)
        echo "  ✓ $lang: $version"
    else
        echo "  ✗ $lang: not found"
    fi
done
echo ""

# Check AI tools
echo "AI Development Tools:"
ai-tools list
echo ""

# Check key npm global packages
echo "NPM Global Packages:"
npm list -g --depth=0 2>/dev/null | grep -E "typescript|vite|prettier|eslint" || echo "  Basic tools not installed"
echo ""

# Check container tools
echo "Container Tools:"
for tool in docker docker-compose kubectl helm k9s; do
    command -v $tool >/dev/null 2>&1 && echo "  ✓ $tool" || echo "  ✗ $tool"
done
echo ""

echo "Run 'ai-tools install' to install AI CLI tools"
echo "Run 'npm install -g <package>' to add more tools"
EOF
chmod +x /usr/local/bin/validate-dev-env

echo ""
echo "========================================="
echo "Development tools installation complete!"
echo "========================================="
echo ""
echo "Run 'validate-dev-env' to check installation"
echo "Run 'ai-tools' for AI CLI tools help"
echo ""