# Your cellar — the one file in this repo that is yours to change.
#
# Identity and anything machine-specific live here (not in flake.nix), so
# a personal fork's values sit in one place and pulling core updates never
# collides with them. Core treats this file as append-only: it adds
# examples, never rewrites your values.
{
  # Identity of your cellar: everything else in the modules references
  # these. cellar.user has no default in base.nix, so clearing it here
  # fails the eval loudly instead of booting a surprise user.
  cellar.user = "randy";
  cellar.uid = 1000;
}
