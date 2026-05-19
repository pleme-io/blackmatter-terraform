{
  description = "Blackmatter Terraform — home-manager module: terraform + terragrunt + shared plugin_cache_dir so every worktree shares one local provider cache";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nixpkgs, substrate, ... }:
    (import "${substrate}/lib/blackmatter-component-flake.nix") {
      inherit self nixpkgs;
      name = "blackmatter-terraform";
      description = "home-manager module — install terraform + terragrunt and manage ~/.terraformrc with plugin_cache_dir so provider downloads happen once per machine, not once per worktree";
      modules.homeManager = ./module;
    };
}
