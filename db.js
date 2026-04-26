{
  "name": "stepcode",
  "private": true,
  "version": "2.0.0",
  "type": "module",
  "scripts": {
    "dev":     "concurrently -n SERVER,CLIENT -c cyan,green \"node server/index.js\" \"vite\"",
    "server":  "node server/index.js",
    "client":  "vite",
    "build":   "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react":          "^18.2.0",
    "react-dom":      "^18.2.0",
    "express":        "^4.18.2",
    "better-sqlite3": "^9.4.3",
    "cors":           "^2.8.5"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.1",
    "vite":                 "^5.0.8",
    "concurrently":         "^8.2.2"
  }
}
