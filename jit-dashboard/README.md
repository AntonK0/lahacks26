# JIT Publisher Dashboard

A React + Vite dashboard for publishers to submit textbook packages for the JIT iPad app. The dashboard uploads avatar animation bundles to Cloudinary, then sends the ISBN, Cloudinary URL, and textbook PDF to the Render-hosted FastAPI backend.

## Prerequisites

- **Node.js** — use a current LTS release. Supported ranges are listed under `engines` in this `package.json`.

## Quick Start

```bash
npm install
npm run dev
```

## Cloudinary Setup

This project uses Cloudinary for avatar package storage. If you don't have a Cloudinary account yet:
- [Sign up for free](https://cld.media/reactregister)
- Find your cloud name in your [dashboard](https://console.cloudinary.com/app/home/dashboard)

## Environment Variables

Create `jit-dashboard/.env` with:

```bash
VITE_UPLOAD_API_URL=https://lahacks26.onrender.com/upload-textbook
VITE_CLOUDINARY_CLOUD_NAME=your_cloud_name
VITE_CLOUDINARY_UPLOAD_PRESET=your_unsigned_upload_preset
VITE_DEFAULT_JIT_CLOUDINARY_URL=https://res.cloudinary.com/.../avatar.usdz
```

`VITE_UPLOAD_API_URL` is optional because the app defaults to the Render endpoint above. Use it when pointing the dashboard at a local FastAPI server.

Uploads require an unsigned Cloudinary upload preset that accepts raw/archive files such as `.zip`.

To create an unsigned upload preset:
1. Go to https://console.cloudinary.com/app/settings/upload/presets
2. Click "Add upload preset"
3. Set it to "Unsigned" mode
4. Allow zip/raw uploads for publisher avatar bundles
5. Add the preset name to your `.env` file
6. Save the `.env` file and restart the dev server so the new values load correctly.

## Avatar Zip Format

For custom avatars, publishers should upload one prebuilt `.zip` file. Put the animation `.usdc` files at the root of the zip so the iPad app can resolve them predictably.

Example zip contents:

```text
Idle.usdc
Wave.usdc
Yes.usdc
No.usdc
```

The dashboard uploads this zip to Cloudinary using the raw upload endpoint and forwards Cloudinary's returned secure URL to FastAPI without rewriting it.

## Backend Contract

The dashboard submits a multipart `POST` request to `/upload-textbook` with:

- `isbn`: the normalized 13-digit ISBN.
- `cloudinary_url`: the default avatar URL or the secure URL returned from the custom Cloudinary zip upload.
- `file`: the textbook PDF file.

## Manual Test Checklist

1. Start the dashboard with `npm run dev`.
2. Enter a 13-digit ISBN and choose a small PDF.
3. Choose the default avatar or upload a zip containing `.usdc` files.
4. Submit the package and confirm the success message shows uploaded chunk metadata.
5. Confirm the Cloudinary secure URL and PDF filename match the submitted package.

## Learn More

- [Cloudinary React SDK Docs](https://cloudinary.com/documentation/react_integration)
- [Vite Documentation](https://vite.dev)
- [React Documentation](https://react.dev)
