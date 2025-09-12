# Setting up GitHub Container Registry (GHCR) Publishing

## Current Issue
The Docker image successfully publishes to Docker Hub but fails on GHCR with:
```
denied: installation not allowed to Write organization package
```

## Solutions

### Option 1: Enable GitHub Actions Package Write Permission (Recommended)

1. Go to: https://github.com/aygp-dr/freebsd-docker/settings/actions

2. Under "Workflow permissions", select:
   - ✅ Read and write permissions
   - ✅ Allow GitHub Actions to create and approve pull requests

3. Click "Save"

### Option 2: Use Personal Access Token (PAT)

1. Create a PAT with `write:packages` scope:
   - Go to: https://github.com/settings/tokens/new
   - Select: `write:packages`, `read:packages`, `delete:packages`
   - Name it: `GHCR_TOKEN`

2. Add to repository secrets:
   - Go to: https://github.com/aygp-dr/freebsd-docker/settings/secrets/actions
   - Add secret: `GHCR_TOKEN` with your PAT value

3. Update workflow to use PAT:
   ```yaml
   - name: Log in to GitHub Container Registry
     uses: docker/login-action@v3
     with:
       registry: ghcr.io
       username: ${{ github.actor }}
       password: ${{ secrets.GHCR_TOKEN }}  # Use PAT instead of GITHUB_TOKEN
   ```

### Option 3: Disable GHCR Publishing (Current Workaround)

Remove GHCR from the workflow to avoid errors:
```yaml
# Comment out or remove the GHCR login and push sections
```

## Current Status

- ✅ **Docker Hub**: Working (`aygpdr/freebsd:14.2-RELEASE`)
- ❌ **GHCR**: Permission denied (`ghcr.io/aygp-dr/freebsd`)

## Testing After Fix

Once permissions are fixed:
```bash
# Trigger a new build
gh workflow run docker-publish.yml

# Or push a commit
git commit --allow-empty -m "test: verify GHCR publishing works"
git push
```

## Version Information

Current configuration:
- FreeBSD Version: 14.2-RELEASE (changed from 14.3)
- Docker Hub: `aygpdr/freebsd:14.2-RELEASE`, `aygpdr/freebsd:latest`
- GHCR (when fixed): `ghcr.io/aygp-dr/freebsd:14.2-RELEASE`

## Notes

- GHCR is preferred for GitHub-hosted projects (better integration)
- Docker Hub has better public discovery
- Having both provides redundancy
- The 14.2 version is more stable than 14.3