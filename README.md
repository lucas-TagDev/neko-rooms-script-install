# Neko Rooms – Installation Guide

This guide explains how to install **Neko Rooms** on a Linux virtual machine using an automated script.

---

## Requirements

Before starting, make sure you have:

* A **Linux virtual machine** (this guide was tested on **Ubuntu 24.04.2 LTS**)
* A **registered domain** (e.g. `.com`, `.net`, etc.)
* A VPS or VM with **firewall access**

  * If your VPS provider or VM uses a firewall, make sure the following ports are **open**:

    * **80** (HTTP)
    * **443** (HTTPS)
    * **8080** (internal Docker service)
    * **59000–59100** (room port range)

---

## Step 1 – Configure Your Domain (DNS)

1. Access the control panel of your domain registrar.
2. Create an **A record** pointing your domain to the **public IP address of your server**.

> 💡 If you are not familiar with DNS configuration, you can ask ChatGPT how to create an A record for your domain registrar.

---

## Step 2 – Download the Installation Script

You can download the script directly from the GitHub repository:

🔗 [https://github.com/lucas-TagDev/neko-rooms-script-install](https://github.com/lucas-TagDev/neko-rooms-script-install)

Or clone it using the terminal:

```bash
git clone https://github.com/lucas-TagDev/neko-rooms-script-install.git
cd neko-rooms-script-install/
chmod +x neko.sh
./neko.sh
```

---

## Step 3 – Script Configuration

During execution, the script will ask for some configuration values.

If you **do not want to customize**, simply press **ENTER** to keep the default values.

Default prompts:

```text
Timezone [UTC]: <ENTER>
Room port range [59000-59100]: <ENTER>
Docker internal port [8080]: <ENTER>
```

---

## Final Notes

* Follow the instructions displayed by the script until the installation is complete.
* If all requirements are correctly met, **Neko Rooms will be fully installed and ready to use**.

If you encounter any issues or have questions, feel free to leave a comment or open an issue in the repository.

✅ Installation complete. Enjoy your Neko Rooms server!


Download images / update
You need to pull all your images, that you want to use with neko-room. Otherwise, you might get this error: (see issue #1).Error response from daemon: No such image:

docker pull ghcr.io/m1k1o/neko/firefox
docker pull ghcr.io/m1k1o/neko/chromium
# etc...
