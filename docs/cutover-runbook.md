# M5 cutover runbook — Sitio Rails on OKE

## What is `RAILS_MASTER_KEY`?

Rails encrypts secrets in `config/credentials.yml.enc` (committed). The **master key**
decrypts that file at boot. Locally it lives in `config/master.key` (gitignored).

In production there is no `master.key` file in the image — you pass the same 32-char
hex string as the env var **`RAILS_MASTER_KEY`**.

Without it the app will not boot (`Missing encryption key to decrypt credentials`).

Your local copy: `sitio-rails/config/master.key` (already on this machine from `rails new`).
Treat it like a password: never commit it, only put it in a SealedSecret / password manager.

View / rotate credentials later with:

```bash
# from sitio-rails
bin/rails credentials:show          # needs master.key present
bin/rails credentials:edit         # opens $EDITOR
```

---

## One-time setup checklist

### 1. Terraform — create OCIR repo `sitio-rails`

```bash
cd ~/Documents/personal-lab/terraform-files/oracle-cluster
terraform plan   # should show oci_artifacts_container_repository.sitio_rails
terraform apply
terraform output sitio_rails_repository_url
# → vcp.ocir.io/<namespace>/sitio-rails
```

### 2. GitHub secrets on `artieeez/sitio-rails`

Copy the same secrets you already use on `sitio-monorepo`:

| Secret | Purpose |
|--------|---------|
| `OCIR_USERNAME` | OCIR auth (usually `namespace/oracleidentitycloudservice/<user>` or tenancy user) |
| `OCIR_AUTH_TOKEN` | OCIR auth token |
| `OCIR_NAMESPACE` | Object storage namespace (e.g. `axtvnrdemzo7`) |
| `ARTR_GITOPS_REPO_TOKEN` | PAT that can push to `artieeez/artr-gitops` |

### 3. Seal `RAILS_MASTER_KEY` (cluster access required)

```bash
# Staging
cat > /tmp/sitio-rails-secrets.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: sitio-rails-secrets
  namespace: sitio-staging
type: Opaque
stringData:
  RAILS_MASTER_KEY: "$(cat ~/Documents/sitio/sitio-rails/config/master.key)"
EOF

kubeseal --format yaml \
  --controller-namespace sealed-secrets \
  --controller-name sealed-secrets \
  < /tmp/sitio-rails-secrets.yaml \
  > ~/Documents/sitio/artr-gitops/apps/sitio-staging/sitio-rails/sitio-rails-secrets-sealed.yaml

# Production (same key is fine — greenfield DB either way)
sed 's/sitio-staging/sitio-production/' /tmp/sitio-rails-secrets.yaml > /tmp/sitio-rails-secrets-prod.yaml
kubeseal --format yaml \
  --controller-namespace sealed-secrets \
  --controller-name sealed-secrets \
  < /tmp/sitio-rails-secrets-prod.yaml \
  > ~/Documents/sitio/artr-gitops/apps/sitio-production/sitio-rails/sitio-rails-secrets-sealed.yaml

rm -f /tmp/sitio-rails-secrets.yaml /tmp/sitio-rails-secrets-prod.yaml
```

Commit the two `*-sealed.yaml` files in `artr-gitops` (never the plaintext).

### 4. Push gitops + Rails + apply terraform

Order that works:

1. `terraform apply` (OCIR repo exists)
2. Commit/push `artr-gitops` (Rails manifests + Argo apps; Nest Argo apps removed)
3. Commit/push `sitio-rails` (workflow + `.env.example`)
4. Seal + push secrets (step 3)
5. Run **Actions → Deploy Rails** on `sitio-rails` (staging first, then production)

### 5. Verify

```bash
kubectl -n sitio-staging get pods,ingressroute,pvc -l app=sitio-rails
kubectl -n sitio-staging logs deploy/sitio-rails --tail=80
curl -sI https://sitio-staging.artr.com.br/up
```

First boot runs `db:prepare` (greenfield SQLite on the PVC). Create the first admin via the registration form (zero users).

Webhook callback for Wix: `https://sitio-staging.artr.com.br/webhooks/wix` (shown under Admin → Wix).

---

## What changed in gitops

- **Added** `apps/sitio-{staging,production}/sitio-rails/` — Deployment (replicas=1, Recreate), Service, PVC (`nfs-client`), IngressRoute (no TinyAuth), `ocir-pull` SealedSecret copy
- **Added** ArgoCD Applications `sitio-*-sitio-rails`
- **Removed** ArgoCD Applications for Nest backend, React dashboard, and Postgres (already at replicas 0). Old YAML trees left under `apps/sitio-*/` with `RETIRED-nestjs-react.md` for archaeology

DNS hostnames are unchanged (`sitio-staging.artr.com.br` / `sitio.artr.com.br`); only the IngressRoute target flips to Rails.
