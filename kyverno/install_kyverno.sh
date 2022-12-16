#!/bin/bash
# Source: https://kyverno.io/docs/introduction/#quick-start

# Add the Helm repository
helm repo add kyverno https://kyverno.github.io/kyverno/

# Scan your Helm repositories to fetch the latest available charts.
helm repo update

# Install the Kyverno Helm chart into a new namespace called "kyverno"
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
