#!/bin/sh

# Strict mode : 
# -e : Exit if a command fails
# -u : Exit if an unset variable is referenced
set -eu

# Resolve absolute script directory and locate .env file
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_PATH="$SCRIPT_DIR/../.env"

if [ ! -f "$ENV_PATH" ]; then
  echo "Error: .env file not found at $ENV_PATH" >&2
  exit 1
fi

# Load environment variables
# with bash use source $ENV_PATH
. "$ENV_PATH"


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
REPO_NAME="$(basename "$GIT_REPO")"

# Get Github repo

if [ -d "$REPO_NAME" ]; then
  echo "Repository exists. Pulling latest changes..."
  cd "$REPO_NAME" && git pull
else
  echo "Cloning repository..."
  git clone "https://github.com/$GIT_REPO.git"
  cd "$REPO_NAME"
fi

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
  echo "$DOCKER_TOKEN" | docker login -u "$DOCKER_USER" --password-stdin
fi

# Build and tag the production Docker image
IMAGE_TAG="$DOCKER_REGISTRY:latest"
echo "Building Docker image: $IMAGE_TAG..."
docker build -t "$IMAGE_TAG" .

# Publish the finalized image to the registry
echo "Pushing image to Docker Hub..."
docker push "$IMAGE_TAG"

echo "Deployment completed successfully!"