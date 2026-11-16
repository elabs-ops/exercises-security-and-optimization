#!/bin/sh

# Strict mode : 
# -e : Exit if a command fails
# -u : Exit if an unset variable is referenced
set -eu


# Validate required CLI dependencies
command -v git >/dev/null 2>&1 || { echo "Error: git is required but missing." >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Error: docker is required but missing." >&2; exit 1; }

# Validate command-line arguments
if [ "$#" -ne 2 ]; then
  echo "Error: Missing arguments." >&2
  echo "Usage: $0 <github-username/repo> <dockerhub-username/image>" >&2
  exit 1
fi

GIT_REPO="$1"
DOCKER_REGISTRY="$2"

# Create a secure, unique isolated temporary directory for the workspace
WORKSPACE=$(mktemp -d)

# Setup automated workspace cleanup on script exit (even on failure)
cleanup() {
  if [ -d "$WORKSPACE" ]; then
    echo "Cleaning up temporary workspace..."
    rm -rf "$WORKSPACE"
  fi
}
trap cleanup EXIT INT TERM

# Clone the targeted GitHub repository directly into our temporary workspace
echo "Cloning repository..."
  git clone "https://github.com/$GIT_REPO.git" "$WORKSPACE"

# Navigate to the workspace
cd "$WORKSPACE"

# Verify Dockerfile presence before initiating build
if [ ! -f Dockerfile ]; then 
  echo "Error: Dockerfile not found in repository root." >&2
  exit 1
fi

# Authenticate with Docker Hub if not already logged in as the correct user
echo "Checking Docker Hub authentication status..."
if docker info 2>/dev/null | grep -q "Username: $DOCKER_USER"; then
  echo "Already authenticated as $DOCKER_USER. Skipping login."
else
  echo "Not authenticated as $DOCKER_USER. Initiating login..."
  echo "$DOCKER_PWD" | docker login -u "$DOCKER_USER" --password-stdin
fi

# Build and tag the production Docker image
IMAGE_TAG="$DOCKER_REGISTRY:latest"
echo "Building Docker image: $IMAGE_TAG..."
docker build -t "$IMAGE_TAG" .

# Publish the finalized image to the registry
echo "Pushing image to Docker Hub..."
docker push "$IMAGE_TAG"

echo "Deployment completed successfully!"