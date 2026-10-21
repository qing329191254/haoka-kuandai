import express from 'express'
import history from 'connect-history-api-fallback'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const dist = path.join(__dirname, 'dist')
const port = Number(process.env.PORT) || 8888

const app = express()
app.use(history())
app.use(express.static(dist))

app.listen(port, '0.0.0.0', () => {
  console.log(`admin static server http://0.0.0.0:${port}`)
})
