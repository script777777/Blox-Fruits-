/// <reference types="vite/client" />

declare const Netlify: {
  env: {
    get(name: string): string | undefined;
  };
};
