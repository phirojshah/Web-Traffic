# Web Traffic 

**Web TRaffic Tool** is designed to significantly increase traffic to your website. It automates crawling and sends requests to website paths while dynamically changing IP addresses using Tor, ensuring efficient and anonymous operations.

## How It Works
1. **Download the Tool**:
   ```bash
   git clone <repository-url>
   cd Web Traffc
   chmod +x traffic.sh
   ```
2. **Run the Tool**:
   ```bash
   ./traffic.sh <example.com>
   ./traffic.sh google.com
   ```

   - The tool will crawl all accessible paths on the provided URL using **Katana**.
   - It will change IP addresses using **Tor** for anonymity.
   - It sends requests to all the crawled paths with the user agent `Mozilla`.

## Requirements

### 1. Install Tor
```bash
sudo apt install tor
```

### 2. Configure Tor
Edit the configuration file:
```bash
sudo vim /etc/tor/torrc
```
Add the following lines:
```
SocksPort 9050
SocksPolicy accept *
ControlPort 9051
CookieAuthentication 0
```
Save and exit.

Run Tor:
```bash
tor
```

### 3. Install tmux (Optional but Recommended)
To manage Tor in a separate terminal session:
```bash
sudo apt install tmux
```

### 4. Install Katana (if not already installed)
```bash
sudo apt update
sudo apt install golang

# Install Katana
go install github.com/projectdiscovery/katana/cmd/katana@latest

# Move Katana binary to a system path
sudo mv ~/go/bin/katana /usr/local/bin
```

## Running the Tool
Once the dependencies are set up, simply execute:
```bash
./traffic.sh <example.com>
```
Replace `<example.com>` with the target domain.

## Features
- **Anonymous IP Cycling**: Keeps your activities anonymous by changing IPs using Tor.
- **Dynamic Path Crawling**: Automatically discovers paths using Katana for a comprehensive traffic boost.
- **User-Agent Customization**: Sends requests mimicking Mozilla, enhancing compatibility.
- **Effortless Setup**: Simple installation and execution process.

---

**Get started today and watch your website traffic soar!**

