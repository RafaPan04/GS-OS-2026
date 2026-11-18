import { useEffect, useState } from 'react'

// A API é chamada por caminho relativo (/api/...): o nginx do container "app"
// repassa para o container "api".
const api = async (caminho, opcoes = {}) => {
  const resp = await fetch(`/api${caminho}`, {
    headers: { 'Content-Type': 'application/json' },
    ...opcoes,
    body: opcoes.body ? JSON.stringify(opcoes.body) : undefined,
  })
  const dados = await resp.json().catch(() => ({}))
  if (!resp.ok) throw new Error(dados.message || `Erro ${resp.status}`)
  return dados
}

export default function App() {
  const [modulos, setModulos] = useState([])
  const [filtro, setFiltro] = useState('')
  const [ocorrencias, setOcorrencias] = useState([])
  const [painel, setPainel] = useState(null)
  const [aberta, setAberta] = useState(null)
  const [nome, setNome] = useState('')
  const [aviso, setAviso] = useState(null)

  const carregar = async () => {
    try {
      const [lista, resumo] = await Promise.all([
        api(`/ocorrencias${filtro ? `?modulo=${filtro}` : ''}`),
        api('/painel'),
      ])
      setOcorrencias(lista)
      setPainel(resumo)
    } catch (e) {
      setAviso({ erro: true, texto: `API indisponível: ${e.message}` })
    }
  }

  useEffect(() => { api('/modulos').then(setModulos).catch(() => {}) }, [])
  useEffect(() => { carregar() }, [filtro])

  // Executa uma ação, mostra o resultado e recarrega a lista
  const acao = async (fn) => {
    if (!nome.trim()) return setAviso({ erro: true, texto: 'Informe seu nome no topo da página.' })
    try {
      const r = await fn()
      setAviso({ erro: false, texto: r.mensagem || 'Feito!' })
      carregar()
    } catch (e) {
      setAviso({ erro: true, texto: e.message })
    }
  }

  const nomeModulo = (id) => modulos.find((m) => m.id === id)?.nome || id

  return (
    <main>
      <header>
        <h1>Colecity</h1>
        <p className="pergunta">
          Quantas pessoas enfrentam o mesmo problema que eu, e onde a cidade precisa agir primeiro?
        </p>
        <input placeholder="Seu nome" value={nome} onChange={(e) => setNome(e.target.value)} />
      </header>

      {aviso && (
        <p className={aviso.erro ? 'aviso erro' : 'aviso'} onClick={() => setAviso(null)}>{aviso.texto}</p>
      )}

      {painel && (
        <section className="painel">
          <h2>Onde agir primeiro</h2>
          <p>
            <b>{painel.totalPessoas}</b> pessoas afetadas em <b>{painel.totalOcorrencias}</b> ocorrências
          </p>
          <ol>
            {painel.ondeAgirPrimeiro.map((o) => (
              <li key={o.id}>
                <b>{o.pessoas} pessoas</b> · {o.titulo} — {o.local} <span className="tag">{nomeModulo(o.modulo)}</span>
              </li>
            ))}
          </ol>
        </section>
      )}

      <nav>
        <button className={filtro === '' ? 'ativo' : ''} onClick={() => setFiltro('')}>Todos</button>
        {modulos.map((m) => (
          <button key={m.id} className={filtro === m.id ? 'ativo' : ''} onClick={() => setFiltro(m.id)}>
            {m.nome}
          </button>
        ))}
      </nav>

      <section>
        {ocorrencias.map((o) => (
          <article key={o.id}>
            <div className="linha" onClick={() => setAberta(aberta === o.id ? null : o.id)}>
              <div className="contador">{o.pessoas}<small>pessoas</small></div>
              <div>
                <h3>{o.titulo}</h3>
                <p>{o.local} <span className="tag">{nomeModulo(o.modulo)}</span></p>
              </div>
            </div>
            <button onClick={() => acao(() => api(`/ocorrencias/${o.id}/apoios`, { method: 'POST', body: { nome } }))}>
              Eu também
            </button>
            {aberta === o.id && <Detalhe ocorrencia={o} onComentar={(texto) =>
              acao(() => api(`/ocorrencias/${o.id}/comentarios`, { method: 'POST', body: { autor: nome, texto } }))} />}
          </article>
        ))}
      </section>

      <NovoRelato modulos={modulos} onEnviar={(relato) =>
        acao(() => api('/ocorrencias', { method: 'POST', body: { ...relato, autor: nome } }))} />
    </main>
  )
}

function Detalhe({ ocorrencia, onComentar }) {
  const [texto, setTexto] = useState('')
  return (
    <div className="detalhe">
      {ocorrencia.descricao && <p>{ocorrencia.descricao}</p>}
      <h4>Comentários</h4>
      {ocorrencia.comentarios.length === 0 && <p className="vazio">Nenhum comentário ainda.</p>}
      {ocorrencia.comentarios.map((c, i) => <p key={i}><b>{c.autor}:</b> {c.texto}</p>)}
      <form onSubmit={(e) => { e.preventDefault(); onComentar(texto); setTexto('') }}>
        <input placeholder="Escreva um comentário" value={texto} onChange={(e) => setTexto(e.target.value)} />
        <button>Comentar</button>
      </form>
    </div>
  )
}

function NovoRelato({ modulos, onEnviar }) {
  const vazio = { modulo: 'TRANSPORTE', titulo: '', local: '', descricao: '' }
  const [relato, setRelato] = useState(vazio)
  const campo = (k) => (e) => setRelato({ ...relato, [k]: e.target.value })
  const rotuloLocal = modulos.find((m) => m.id === relato.modulo)?.rotuloLocal || 'Local'

  return (
    <section className="relato">
      <h2>Relatar um problema</h2>
      <p className="vazio">Se alguém já relatou o mesmo problema, você entra no abaixo-assinado dele.</p>
      <form onSubmit={(e) => { e.preventDefault(); onEnviar(relato); setRelato(vazio) }}>
        <select value={relato.modulo} onChange={campo('modulo')}>
          {modulos.map((m) => <option key={m.id} value={m.id}>{m.nome}</option>)}
        </select>
        <input placeholder="O que está acontecendo? (ex.: Ônibus não passa no horário)" value={relato.titulo} onChange={campo('titulo')} />
        <input placeholder={rotuloLocal} value={relato.local} onChange={campo('local')} />
        <textarea placeholder="Detalhes (opcional)" value={relato.descricao} onChange={campo('descricao')} />
        <button>Enviar relato</button>
      </form>
    </section>
  )
}
