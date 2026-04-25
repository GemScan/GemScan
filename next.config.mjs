/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  trailingSlash: true,
  images: { unoptimized: true },
  env: {
    NEXT_PUBLIC_APP_VERSION: process.env.npm_package_version ?? '0.0.0',
    NEXT_PUBLIC_IS_MOCK: process.env.NEXT_PUBLIC_IS_MOCK ?? 'false',
  },
}

export default nextConfig
