#!/usr/bin/env sh

yes Y | corepack enable
CI=true pnpm install --frozen-lockfile
pnpm start
