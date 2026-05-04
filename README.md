# BAK PDF App

Flutter Android app untuk membuat beberapa file PDF dari gambar yang dipilih per BAK.

## Fitur

- Tambah dan hapus BAK.
- Pilih banyak gambar per BAK menggunakan `file_picker`.
- Hapus gambar dari BAK.
- Generate semua BAK menjadi PDF dengan tombol `Proses Semua`.
- Setiap gambar menjadi satu halaman PDF portrait tanpa watermark.
- Simpan PDF ke `/storage/emulated/0/Documents/BAK_PDF/`.
- Bagikan PDF hasil generate menggunakan `share_plus`.
- Meminta izin storage agar bisa menulis ke folder Documents publik di Android.

## Menjalankan

Pastikan Flutter SDK sudah tersedia di PATH, lalu jalankan:

```bash
flutter pub get
flutter run
```
