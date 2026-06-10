# Diodonfrost Exherbo Repository

A third-party Exherbo Linux package repository providing exheres for DevOps, infrastructure, and desktop tools not available in the main repositories.

## Quick Start

Add the repository configuration to Paludis:

```bash
cat > /etc/paludis/repositories/diodonfrost.conf << 'EOF'
format = e
location = /var/db/paludis/repositories/diodonfrost
sync = git+https://gitlab.exherbo.org/diodonfrost/exheres.git
masters = arbor
EOF

cave sync diodonfrost
```

## Available Packages

| Category | Package | Description |
|----------|---------|-------------|
| app-accessibility | [handy](https://handy.computer) | Offline speech-to-text desktop application |
| app-admin | [helm](https://helm.sh) | Kubernetes package manager |
| app-admin | [kubectl](https://kubernetes.io) | Kubernetes command-line tool |
| app-admin | [packer](https://www.packer.io) | Automated machine image builder |
| app-admin | [pulumi](https://www.pulumi.com) | Infrastructure as Code SDK |
| app-admin | [terraform](https://www.terraform.io) | Infrastructure as Code tool |
| app-admin | [terragrunt](https://terragrunt.gruntwork.io) | Thin wrapper for Terraform |
| app-admin | [vagrant](https://www.vagrantup.com) | Development environment manager |
| app-crypt | [sops](https://github.com/getsops/sops) | Encrypted file editor for secrets |
| dev-build | [just](https://just.systems) | Command runner (alternative to Make) |
| dev-lang | [zig](https://ziglang.org) | General-purpose programming language and toolchain |
| dev-node | [bun-bin](https://bun.sh) | JavaScript runtime and toolkit (pre-built binary) |
| dev-util | [github-cli](https://cli.github.com) | GitHub CLI |
| dev-util | [glab](https://gitlab.com/gitlab-org/cli) | GitLab CLI |
| dev-util | [inspec](https://www.inspec.io) | Infrastructure compliance testing |
| kde-plasma | [plasma-meta](https://kde.org/plasma-desktop) | KDE Plasma desktop meta-package |
| www-client | [servo](https://servo.org) | Independent web rendering engine |

## Build Testing

Packages are built and tested by the official Exherbo CI. Every push opens a
pipeline that runs `buildtest` (from the `exherbo/exherbo_ci` image): it detects
the `.exheres-0`/`.exlib` files changed in the branch, syncs the repository to
that commit and resolves + builds each affected package. Open a merge request
and the pipeline validates your change automatically.

The same pipeline is defined in [`.gitlab-ci.yml`](.gitlab-ci.yml).
