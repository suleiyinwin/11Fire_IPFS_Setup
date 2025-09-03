set -e  # Exit on any error

echo "=========================================="
echo "IPFS Kubo Auto Setup - Linux"
echo "=========================================="

# Configuration
KUBO_VERSION="v0.34.1"
BOOTSTRAP_NODE="/ip4/10.4.56.71/tcp/4001/p2p/12D3KooWB8e8PHhq1GbdeZk9Y6fLUBYu6AqZKjs15zQZaGrYHxu9"

# Check if swarm key is provided via environment variable
if [ -z "$IPFS_SWARM_KEY" ]; then
    echo "Error: IPFS_SWARM_KEY environment variable is not set!"
    echo "Please set it before running this script:"
    echo "   export IPFS_SWARM_KEY='/key/swarm/psk/1.0.0/'"
    echo "   export IPFS_SWARM_KEY='\$IPFS_SWARM_KEY'"
    echo "   export IPFS_SWARM_KEY='\$IPFS_SWARM_KEY/base16/'"
    echo "   export IPFS_SWARM_KEY='\$IPFS_SWARM_KEY<your-64-char-hex-key>'"
    echo ""
    echo "   Or as a one-liner:"
    echo "   export IPFS_SWARM_KEY='/key/swarm/psk/1.0.0//base16/0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'"
    exit 1
fi

echo "Swarm key found in environment variable"

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_NAME="amd64"
        ;;
    aarch64)
        ARCH_NAME="arm64"
        ;;
    armv7l)
        ARCH_NAME="arm"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

DOWNLOAD_URL="https://dist.ipfs.tech/kubo/${KUBO_VERSION}/kubo_${KUBO_VERSION}_linux-${ARCH_NAME}.tar.gz"
TAR_FILE="kubo_${KUBO_VERSION}_linux-${ARCH_NAME}.tar.gz"

echo "Step 1: Downloading IPFS Kubo ${KUBO_VERSION} for ${ARCH_NAME}..."
if command -v wget &> /dev/null; then
    wget -q --show-progress "$DOWNLOAD_URL"
elif command -v curl &> /dev/null; then
    curl -L -o "$TAR_FILE" "$DOWNLOAD_URL"
else
    echo "Error: Neither wget nor curl is available. Please install one of them."
    exit 1
fi

echo "Step 2: Extracting archive..."
tar -xzf "$TAR_FILE"

echo "Step 3: Installing IPFS..."
cd kubo
sudo bash install.sh

echo "Step 4: Verifying installation..."
ipfs --version

echo "Step 5: Initializing IPFS..."
if [ -d "$HOME/.ipfs" ]; then
    echo "⚠️ IPFS already initialized, skipping init..."
else
    ipfs init
fi

echo "Step 6: Creating swarm key from environment variable..."
echo "$IPFS_SWARM_KEY" > "$HOME/.ipfs/swarm.key"
echo "Swarm key created at: $HOME/.ipfs/swarm.key"

# Validate swarm key format (basic check)
if ! grep -q "^/key/swarm/psk/" "$HOME/.ipfs/swarm.key"; then
    echo "Warning: Swarm key format may be invalid. Expected format:"
    echo "   /key/swarm/psk/1.0.0/"
    echo "   /base16/"
    echo "   <64-character-hex-key>"
fi

echo "Step 7: Configuring bootstrap nodes..."
ipfs bootstrap rm --all
ipfs bootstrap add "$BOOTSTRAP_NODE"

echo "Step 8: Configuring IPFS settings..."
ipfs config --json Routing '{ "Type": "dhtserver" }'
ipfs config AutoTLS.Enabled false --bool
ipfs config --json Swarm.Transports.Network.Websocket false

echo "🧹 Step 9: Cleaning up..."
cd ..
rm -rf kubo "$TAR_FILE"

echo "=========================================="
echo "IPFS Setup Complete!"
echo "=========================================="
echo "Configuration Summary:"
echo "• Bootstrap nodes:"
ipfs bootstrap list
echo "• Swarm key: $HOME/.ipfs/swarm.key"
echo "• Private network: Enabled"
echo ""
echo "To start IPFS daemon:"
echo "  ipfs daemon"
echo ""
echo "To check connected peers:"
echo "  ipfs swarm peers"
echo ""
echo "Security Note: Swarm key loaded from IPFS_SWARM_KEY environment variable"
echo "=========================================="