# blackmatter-terraform

Home-manager module — install `terraform` + `terragrunt` and manage `~/.terraformrc` so every `terraform init` across every worktree, every terragrunt unit, every `.terragrunt-cache/.../` shares a single local provider plugin cache.

## Why

Without a shared plugin cache, every fresh `terraform init` re-downloads every provider — `hashicorp/aws` alone is ~250 MB and routinely takes 4-15 minutes over a flaky link. The pain is multiplicative across:

- multiple git worktrees (each has its own `.terragrunt-cache/`)
- multiple terragrunt units (each unit's `.terragrunt-cache/...` is a separate `.terraform/`)
- bumped provider versions invalidating the cache
- new operators onboarding to a repo

This module turns provider downloads into a one-time per-version event, machine-wide.

## What it does

1. Installs `pkgs.terraform` and `pkgs.terragrunt` into the user profile (toggle via `installPackages`).
2. Writes `~/.terraformrc` containing `plugin_cache_dir = "<resolved absolute path>"`.
3. Creates the plugin cache directory (`~/.terraform.d/plugin-cache/`) on activation.
4. Optionally exports `TF_PLUGIN_CACHE_DIR` in `home.sessionVariables` as a fallback (`exportEnv = true`).

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | bool | `false` | Enable the module. |
| `terraformPackage` | package | `pkgs.terraform` | Override the terraform CLI version. |
| `terragruntPackage` | package | `pkgs.terragrunt` | Override the terragrunt CLI version. |
| `installPackages` | bool | `true` | Install both packages into the user profile. Disable when per-repo dev shells provide them and the module's job is just `.terraformrc`. |
| `pluginCacheDir` | str | `~/.terraform.d/plugin-cache` | Where terraform stashes provider tarballs. Resolved to a literal absolute path at eval time. |
| `exportEnv` | bool | `false` | Also export `TF_PLUGIN_CACHE_DIR` in the session env. |
| `extraConfig` | lines | `""` | Extra HCL appended verbatim to `~/.terraformrc`. |

## Enabling

In your consumer home-manager profile:

```nix
blackmatter.components.terraform.enable = true;
```

For a custom plugin cache location (e.g. a fast SSD path):

```nix
blackmatter.components.terraform = {
  enable = true;
  pluginCacheDir = "/Volumes/scratch/terraform-plugin-cache";
};
```

For per-repo dev-shell-only terraform (skip user-profile install, just manage `.terraformrc`):

```nix
blackmatter.components.terraform = {
  enable = true;
  installPackages = false;
};
```

## Verifying

After rebuild:

```bash
cat ~/.terraformrc
# expect: plugin_cache_dir = "/Users/<you>/.terraform.d/plugin-cache"

ls -la ~/.terraform.d/plugin-cache/
# expect: a .keep symlink to nix store + a writable directory

# Next terragrunt apply / terraform init populates the cache:
ls ~/.terraform.d/plugin-cache/registry.terraform.io/hashicorp/aws/
# expect: provider binaries by version
```

A second `terraform init` against a different terragrunt unit / worktree will see provider versions already in the cache and skip the download entirely.

## Wiring into the central blackmatter aggregator

In `github:pleme-io/blackmatter` `flake.nix`:

1. Add the flake input alongside the other extracted components:
   ```nix
   blackmatter-terraform = {
     url = "github:pleme-io/blackmatter-terraform";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```
2. Register in `componentInputs`:
   ```nix
   terraform = inputs.blackmatter-terraform;
   ```
3. Import the home-manager module in the `homeManagerModules.blackmatter` aggregator:
   ```nix
   inputs.blackmatter-terraform.homeManagerModules.default
   ```

Then `nix run .#rebuild` from `~/code/github/pleme-io/nix`.
