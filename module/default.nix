# blackmatter-terraform home-manager module
#
# Installs terraform + terragrunt and manages ~/.terraformrc so every
# `terraform init` across every worktree, every terragrunt unit, every
# `.terragrunt-cache/.../` shares a single local provider plugin cache.
# Eliminates the cold 5-15 min provider download every time the operator
# creates a new worktree or works on a new terragrunt unit — which is a
# real workflow regression for IaC repos like akeyless-environments where
# each region's `canary-test/` lives in its own cache directory.
#
# Why managed via blackmatter — operator workstations need this to be
# consistent across the fleet. The alternative (manual `~/.terraformrc`
# edit) leaks per-operator state, doesn't survive home rebuilds cleanly,
# and isn't discoverable for newcomers.
#
# Namespace: blackmatter.components.terraform.*
{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.blackmatter.components.terraform;
in {
  options.blackmatter.components.terraform = {
    enable = mkEnableOption "blackmatter-terraform (terraform + terragrunt + shared plugin cache)";

    terraformPackage = mkOption {
      type = types.package;
      default = pkgs.terraform;
      description = ''
        terraform CLI to install. Defaults to `pkgs.terraform` from the
        consumer flake's nixpkgs pin. Override to pin a specific version
        (e.g. `pkgs.terraform_1_9`).
      '';
    };

    terragruntPackage = mkOption {
      type = types.package;
      default = pkgs.terragrunt;
      description = "terragrunt CLI to install (defaults to pkgs.terragrunt).";
    };

    installPackages = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install terraform + terragrunt into the user profile. Disable
        when the operator wants terraform/terragrunt only from per-repo
        nix dev shells and the module's job is purely ~/.terraformrc
        management.
      '';
    };

    pluginCacheDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.terraform.d/plugin-cache";
      description = ''
        Directory terraform will use as its shared provider plugin
        cache. Resolved at evaluation time to a literal absolute path
        so it doesn't depend on $HOME being expanded by the
        .terraformrc parser.
      '';
    };

    exportEnv = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Also export TF_PLUGIN_CACHE_DIR in home.sessionVariables.
        Belt-and-suspenders: ~/.terraformrc is the canonical mechanism
        but the env var is the override path some CI runners look at
        when HOME is unusual or .terraformrc is masked.
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Extra HCL appended verbatim to ~/.terraformrc. Use for
        operator-specific knobs (provider_installation network_mirror,
        credentials_helper, etc.) that aren't part of the cache flow.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = lib.mkIf cfg.installPackages [
      cfg.terraformPackage
      cfg.terragruntPackage
    ];

    # ~/.terraformrc — canonical plugin_cache_dir wiring.
    home.file.".terraformrc".text =
      ''
        # Managed by blackmatter-terraform — do not edit by hand.
        # Source:  github:pleme-io/blackmatter-terraform → module/default.nix
        # Option:  blackmatter.components.terraform.pluginCacheDir
        plugin_cache_dir = "${cfg.pluginCacheDir}"
      ''
      + optionalString (cfg.extraConfig != "") ''

        # ── extraConfig (blackmatter.components.terraform.extraConfig) ────
        ${cfg.extraConfig}
      '';

    # Ensure the plugin cache directory exists. Writing a sentinel
    # file via home.file is the cleanest cross-platform way — HM
    # auto-creates the parent dir for us, and terraform happily writes
    # provider tarballs alongside the sentinel.
    home.file.".terraform.d/plugin-cache/.keep".text = "";

    home.sessionVariables = mkIf cfg.exportEnv {
      TF_PLUGIN_CACHE_DIR = cfg.pluginCacheDir;
    };
  };
}
