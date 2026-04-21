module.exports = async ({ github, context, core }) => {
  const owner         = context.repo.owner
  const projectNumber = 2

  const fmtDate = iso => iso
    ? new Date(iso + 'T00:00:00').toLocaleDateString('pt-BR')
    : '—'

  const daysBetween = (isoA, isoB) => {
    const a = new Date(isoA.includes('T') ? isoA : isoA + 'T00:00:00')
    const b = new Date(isoB.includes('T') ? isoB : isoB + 'T00:00:00')
    return Math.round((b - a) / (1000 * 60 * 60 * 24))
  }

  const today = new Date().toISOString().split('T')[0]

  const query = `
    query($owner: String!, $number: Int!, $cursor: String) {
      user(login: $owner) {
        projectV2(number: $number) {
          items(first: 100, after: $cursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              content {
                ... on Issue {
                  number
                  title
                  closedAt
                  repository {
                    owner { login }
                    name
                  }
                }
              }
              fieldValues(first: 30) {
                nodes {
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    name
                    field { ... on ProjectV2SingleSelectField { name } }
                  }
                  ... on ProjectV2ItemFieldDateValue {
                    date
                    field { ... on ProjectV2Field { name } }
                  }
                  ... on ProjectV2ItemFieldNumberValue {
                    number
                    field { ... on ProjectV2Field { name } }
                  }
                }
              }
            }
          }
        }
      }
    }
  `

  let allItems = []
  let cursor   = null
  while (true) {
    const result = await github.graphql(query, { owner, number: projectNumber, cursor })
    const page   = result.user.projectV2.items
    allItems     = allItems.concat(page.nodes)
    if (!page.pageInfo.hasNextPage) break
    cursor = page.pageInfo.endCursor
  }

  console.log('Total de itens: ' + allItems.length)

  for (const item of allItems) {
    const content = item.content
    if (!content?.number) continue

    const issueNumber = content.number
    const repoOwner   = content.repository.owner.login
    const repo        = content.repository.name

    const fields    = item.fieldValues.nodes
    const getDate   = n => fields.find(f => f?.field?.name === n)?.date   ?? null
    const getNumber = n => fields.find(f => f?.field?.name === n)?.number ?? null
    const getSelect = n => fields.find(f => f?.field?.name === n)?.name   ?? null

    const status     = getSelect('Status')
    const startDate  = getDate('Start date')
    const targetDate = getDate('Target date')
    const estimate   = getNumber('Estimate')

    if (!status || status === 'Backlog') continue

    const { data: comments } = await github.rest.issues.listComments({
      owner: repoOwner, repo,
      issue_number: issueNumber,
      per_page: 100
    })

    const jaTemTracker = comments.some(c => c.body.includes('<!-- column-tracker -->'))
    if (jaTemTracker) {
      console.log('  → #' + issueNumber + ' ja tem tracker, pulando.')
      continue
    }

    let body = ''

    if (status === 'Done') {
      const closedAt = content.closedAt ? content.closedAt.split('T')[0] : today

      let prazoAnalysis = 'Nenhuma Target date definida.'
      if (targetDate) {
        const diff = daysBetween(targetDate, closedAt)
        if (diff > 0) {
          prazoAnalysis = 'Entrega atrasada — prazo era ' + fmtDate(targetDate) + ', atraso de ' + diff + ' dia(s)'
        } else if (diff === 0) {
          prazoAnalysis = 'Entrega no prazo — entregue em ' + fmtDate(targetDate)
        } else {
          prazoAnalysis = 'Entrega adiantada — ' + Math.abs(diff) + ' dia(s) antes do prazo (' + fmtDate(targetDate) + ')'
        }
      }

      const prazoTotalDias = (startDate && targetDate)
        ? daysBetween(startDate, targetDate) + ' dia(s)'
        : '—'

      const tempoReal = startDate
        ? daysBetween(startDate, closedAt) + ' dia(s)'
        : '—'

      body = [
        '<!-- column-tracker -->',
        '## Task concluida — Relatorio Final (backfill)',
        '',
        prazoAnalysis,
        '',
        '---',
        '',
        '| Campo | Valor |',
        '|---|---|',
        '| Start date prevista | ' + fmtDate(startDate) + ' |',
        '| Target date | ' + fmtDate(targetDate) + ' |',
        '| Estimativa original | ' + (estimate != null ? estimate + ' horas' : '—') + ' |',
        '| Fechada em | ' + fmtDate(closedAt) + ' |',
        '| Janela de prazo | ' + prazoTotalDias + ' |',
        '| Tempo real (start → close) | ' + tempoReal + ' |',
        '',
        '> Este relatorio foi gerado retroativamente via backfill.',
        '> O tempo por coluna nao esta disponivel pois as transicoes ocorreram antes do tracker ser instalado.',
        '',
        '_Rastreio automático de coluna._'
      ].join('\n')
    }

    else if (status === 'In Progress') {
      const diasDesdeStart = startDate ? daysBetween(startDate, today) : null
      const diasAteTarget  = targetDate ? daysBetween(today, targetDate) : null

      let prazoMsg = ''
      if (diasAteTarget !== null) {
        if (diasAteTarget > 0)      prazoMsg = 'Ainda dentro do prazo — ' + diasAteTarget + ' dia(s) restantes'
        else if (diasAteTarget === 0) prazoMsg = 'Prazo e hoje!'
        else                          prazoMsg = 'Ja esta ' + Math.abs(diasAteTarget) + ' dia(s) atrasado'
      }

      body = [
        '<!-- column-tracker -->',
        '## Em Desenvolvimento — Snapshot atual (backfill)',
        '',
        '| Campo | Valor |',
        '|---|---|',
        '| Snapshot em | ' + fmtDate(today) + ' |',
        '| Start date prevista | ' + fmtDate(startDate) + ' |',
        '| Target date | ' + fmtDate(targetDate) + ' |',
        '| Estimativa | ' + (estimate != null ? estimate + ' horas' : '—') + ' |',
        '| Dias desde o start | ' + (diasDesdeStart != null ? diasDesdeStart + ' dia(s)' : '—') + ' |',
        prazoMsg ? '| Situacao do prazo | ' + prazoMsg + ' |' : '',
        '',
        '_Rastreio automático de coluna._'
      ].join('\n')
    }

    else if (status === 'In Review') {
      const diasAteTarget = targetDate ? daysBetween(today, targetDate) : null

      let prazoMsg = ''
      if (diasAteTarget !== null) {
        if (diasAteTarget > 0)        prazoMsg = 'Ainda dentro do prazo — ' + diasAteTarget + ' dia(s) restantes'
        else if (diasAteTarget === 0) prazoMsg = 'Prazo e hoje — review urgente!'
        else                          prazoMsg = 'Ja esta ' + Math.abs(diasAteTarget) + ' dia(s) atrasado'
      }

      body = [
        '<!-- column-tracker -->',
        '## Em Review — Snapshot atual (backfill)',
        '',
        '| Campo | Valor |',
        '|---|---|',
        '| Snapshot em | ' + fmtDate(today) + ' |',
        '| Start date prevista | ' + fmtDate(startDate) + ' |',
        '| Target date | ' + fmtDate(targetDate) + ' |',
        '| Estimativa | ' + (estimate != null ? estimate + ' horas' : '—') + ' |',
        prazoMsg ? '| Situacao do prazo | ' + prazoMsg + ' |' : '',
        '',
        '_Rastreio automático de coluna._'
      ].join('\n')
    }

    else if (status === 'Adjustment') {
      const diasAteTarget = targetDate ? daysBetween(today, targetDate) : null

      let prazoMsg = ''
      if (diasAteTarget !== null) {
        if (diasAteTarget > 0)        prazoMsg = 'Ainda dentro do prazo, mas restam apenas ' + diasAteTarget + ' dia(s)'
        else if (diasAteTarget === 0) prazoMsg = 'Prazo e hoje!'
        else                          prazoMsg = 'Ja esta ' + Math.abs(diasAteTarget) + ' dia(s) atrasado'
      }

      body = [
        '<!-- column-tracker -->',
        '## Em Adjustment — Snapshot atual (backfill)',
        '',
        '| Campo | Valor |',
        '|---|---|',
        '| Snapshot em | ' + fmtDate(today) + ' |',
        '| Start date prevista | ' + fmtDate(startDate) + ' |',
        '| Target date | ' + fmtDate(targetDate) + ' |',
        '| Estimativa | ' + (estimate != null ? estimate + ' horas' : '—') + ' |',
        prazoMsg ? '| Situacao do prazo | ' + prazoMsg + ' |' : '',
        '',
        '### Motivo do ajuste:',
        '-',
        '',
        '_Rastreio automático de coluna._'
      ].join('\n')
    }

    else if (status === 'Ready') {
      body = [
        '<!-- column-tracker -->',
        '## Pronta para iniciar — Snapshot atual (backfill)',
        '',
        '| Campo | Valor |',
        '|---|---|',
        '| Snapshot em | ' + fmtDate(today) + ' |',
        '| Start date prevista | ' + fmtDate(startDate) + ' |',
        '| Target date | ' + fmtDate(targetDate) + ' |',
        '| Estimativa | ' + (estimate != null ? estimate + ' horas' : '—') + ' |',
        '',
        '> Task aguardando inicio do desenvolvimento.',
        '',
        '_Rastreio automático de coluna._'
      ].join('\n')
    }

    if (!body) continue

    await github.rest.issues.createComment({
      owner: repoOwner, repo,
      issue_number: issueNumber,
      body
    })

    console.log('  → #' + issueNumber + ' [' + status + '] comentario adicionado')
    await new Promise(r => setTimeout(r, 500))
  }
}