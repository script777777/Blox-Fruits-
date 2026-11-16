# VAIs rebuild

The rebuilt VAIs app lives in [`vais/`](./vais/).

The Cursor GitHub App cannot create a new repository from this environment.
To give VAIs its own repo:

1. On GitHub, create an empty public repo `script777777/VAIs`
2. Grant the **Cursor** GitHub App access to that repo
3. Tell the agent to push `vais/` into it

Until then you can run it from this folder:

```bash
cd vais
cp .env.example .env   # add GROQ_API_KEY
npm install
npm run dev
```
