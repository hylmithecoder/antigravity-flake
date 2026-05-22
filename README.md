# Antigravity IDE Nix Flake

Nix Flake untuk menginstal **Google Antigravity IDE** versi `2.0.2` (versi stabil terbaru) di Linux.

Flake ini menyediakan dua varian paket:
1. **`google-antigravity`** (Default): Menggunakan FHS environment (`buildFHSEnv` via Bubblewrap) untuk isolasi yang aman dan kompatibilitas penuh.
2. **`google-antigravity-no-fhs`**: Menggunakan `autoPatchelfHook` untuk menambal binary secara langsung. Menghindari sandbox Bubblewrap sehingga perintah seperti `sudo` dapat berfungsi di terminal terintegrasi IDE.

---

## 🚀 Cara Penggunaan

### 1. Uji Coba Cepat (Tanpa Instalasi)
Anda dapat langsung menjalankan Antigravity IDE secara temporer menggunakan perintah berikut:

```bash
# Varian FHS (Default)
nix run github:hylmithecoder/antigravity-flake

# Varian Non-FHS
nix run github:hylmithecoder/antigravity-flake#google-antigravity-no-fhs
```

### 2. Integrasi ke Home Manager
Untuk menginstalnya secara permanen menggunakan Home Manager, tambahkan input berikut pada `flake.nix` Home Manager Anda:

```nix
inputs = {
  antigravity-flake.url = "github:hylmithecoder/antigravity-flake";
  # Atau jika ingin menggunakan folder lokal untuk pengembangan:
  # antigravity-flake.url = "path:/home/hylmi/flakes/antigravity-2.0-flake";
};
```

Kemudian tambahkan paketnya ke dalam daftar `home.packages` di `home.nix` Anda:

```nix
home.packages = [
  inputs.antigravity-flake.packages.${pkgs.system}.default
];
```

---

## 🛠️ Cara Build Lokal

Jika Anda mengkloning repositori ini secara lokal, Anda bisa melakukan build dengan perintah:

```bash
# Build varian FHS
nix build .#google-antigravity --impure

# Build varian Non-FHS
nix build .#google-antigravity-no-fhs --impure
```

Hasil build akan tersedia di folder `./result/bin/antigravity`.
