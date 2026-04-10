/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: process.env.NEXT_OUTPUT_MODE === 'export' ? 'export' : 'standalone',
};

module.exports = nextConfig;
