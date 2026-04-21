module.exports = async ({ github, context, core }) => {
  const owner = context.repo.owner
  const repo  = context.repo.repo

  const fmtDate = iso => iso
    ? new Date(iso + 'T00:00:00').toLocaleDateString('pt-BR')
    : '---'

  const daysBetween = (isoA, isoB) => {
    const a = new Date(isoA.includes('T') ? isoA : isoA + 'T00:00:00')
    const b = new Date(isoB.includes('T') ? isoB : isoB + 'T00:00:00')
    return Math.round((b - a) / (1000 * 60 * 60 * 24))
  }

  const today = new Date().toISOString().split('T')[0]
  const TRACKER_TAG = '<!-- column-tracker -->'
  const PROJECT_NUMBER = 2

  // Busca dados do projeto para uma issue
  const getProjectData = async (issueNumber) => {
    const query = `
      query($owner: String!, $number: Int!) {
        user(login: $owner) {
          projectV2(number: $number) {
            items(first: 100) {
              nodes {
                content {
                  ... on Issue { number }
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
    const result = await github.graphql(query, { owner, number: PROJECT_NUMBER })
    const items  = result.user.projectV2.items.nodes
    return items.find(i => i.content?.number === issueNumber) ?? null
  }

  const buildComment = (status, fields, today, trackerComments, closedAt) => {
    const getDate   = n => fields.find(f => f?.field?.name === n)?.date   ?? null
    const getNumber = n => fields.find(f => f?.field?.name === n)?.number ?? null

    const startDate  = getDate('Start date')
    const targetDate = getDate('Target date')
    const estimate   = getNumber('Estimate')

    const lastTracker     = trackerComments.at(-1)
    const lastTrackerDate = lastTracker ? lastTracker.created_at.split('T')[0] : today
    const daysInPrev      = daysBetween(lastTrackerDate, today)

    const estimateStr = estimate != null ? estimate + ' horas' : '---'

    if (status === 'Ready') {
      return [
        TRACKER_TAG,
        '## Tarefa pronta para iniciar',
        '',
        '| Campo | Valor |',
        '|---|---|',
        '| Start date prevista | ' + fmtDate(startDate) + ' |',
        '| Target date | ' + fmtDate(targetDate) + ' |',
        '| Estimativa | ' + estimateStr + ' |',
        '',
        'Task movida para Ready, aguardando inicio do desenvolvimento.',
        '',
        '_Rastreio automatico de coluna._'
      ].join('\n')
    }

    if (status === 'In Progress') {
      const prazoTotal = (startDate && targetDate)
        ? daysBetween(startDate, targetDate) + ' dias'
        : '---'
      return [
        TRACKER_TAG,
        '## Desenvolvimento iniciado',
        '',
        '| Campo | Valor |',
        '|---|---|',
        '| Iniciado em | ' + fmtDate(today) + ' |',
        '| Start date prevista | ' + fmtDate(startDate) + ' |',
        '| Target date | ' + fmtDate(targetDate) + ' |',
        '| Estimativa | ' + estimateStr + ' |',
        '| Janela total de prazo | ' + prazoTotal + ' |',
        '| Tempo na coluna anterior | ' + daysInPrev + ' dia(s) |',
        '',
        '_Rastreio automatico de coluna._'
      ].join('\n')
    }

    if (status === 'In Review') {
      const diff = targetDate ? daysBetween(today, targetDate) : null
      const prazoStr = diff === null ? '---'
        : diff > 0  ? diff + ' dia(s) restantes'
        : diff === 0 ? 'Prazo e hoje'
        : Math.abs(diff) + ' dia(s) atrasado'
      return [
        TRACKER_TAG,
        '## Enviado para Review',
        '',
        '| Campo | Valor |',
        '|---|---|',
        '| Data | ' + fmtDate(today) + ' |',
        '| Target date | ' + fmtDate(targetDate) + ' |',
        '| Tempo em In Progress | ' + daysInPrev + ' dia(s) |',
        '| Situacao do prazo | ' + prazoStr + ' |',
        '',
        '_Rastreio automatico de coluna._'
      ].join('\n')
    }

    if (status === 'Adjustment') {
      const diff = targetDate ? daysBetween(today, targetDate) : null
      const prazoStr = diff === null ? '---'
        : diff > 0  ? 'Dentro do prazo, restam ' + diff + ' dia(s)'
        : diff === 0 ? 'Prazo e hoje'
        : Math.abs(diff) + ' dia(s) atrasado'
      return [
        TRACKER_TAG,
        '## Voltou para Adjustment',
        '',
        '| Campo | Valor |',
        '|---|---|',
        '| Data | ' + fmtDate(today) + ' |',
        '| Target date | ' + fmtDate(targetDate) + ' |',
        '| Tempo em In Review | ' + daysInPrev + ' dia(s) |',
        '| Situacao do prazo | ' + prazoStr + ' |',
        '',
        '### Motivo do ajuste:',
        '-',
        '',
        '_Rastreio automatico de coluna._'
      ].join('\n')
    }

    if (status === 'Done') {
      const refDate = closedAt ? closedAt.split('T')[0] : today

      // Tempo por coluna
      const colTimes = {}
      for (let i = 0; i < trackerComments.length; i++) {
        const c    = trackerComments[i]
        const next = trackerComments[i + 1]?.created_at ?? new Date().toISOString()
        const dur  = daysBetween(c.created_at.split('T')[0], next.split('T')[0])
        let col = ''
        if (c.body.includes('pronta para iniciar'))      col = 'Ready'
        else if (c.body.includes('Desenvolvimento iniciado')) col = 'In Progress'
        else if (c.body.includes('In Review') || c.body.includes('para Review')) col = 'In Review'
        else if (c.body.includes('Adjustment'))          col = 'Adjustment'
        if (col) colTimes[col] = (colTimes[col] ?? 0) + dur
      }

      const maxEntry = Object.entries(colTimes).sort((a, b) => b[1] - a[1])[0]
      const totalDias = Object.values(colTimes).reduce((a, b) => a + b, 0)
      const adjustCycles = trackerComments.filter(c => c.body.includes('Voltou para Adjustment')).length

      const colOrder = ['Ready', 'In Progress', 'In Review', 'Adjustment']
      const timeLines = colOrder
        .filter(col => colTimes[col] != null)
        .map(col => {
          const isMax = maxEntry && maxEntry[0] === col
          return '| ' + col + (isMax ? ' (mais tempo)' : '') + ' | ' + colTimes[col] + ' dia(s) |'
        })

      let prazoLine = 'Target date nao definida.'
      if (targetDate) {
        const diff = daysBetween(targetDate, refDate)
        if (diff > 0)       prazoLine = 'Entrega atrasada: prazo era ' + fmtDate(targetDate) + ', atraso de ' + diff + ' dia(s).'
        else if (diff === 0) prazoLine = 'Entrega no prazo em ' + fmtDate(targetDate) + '.'
        else                 prazoLine = 'Entrega adiantada: ' + Math.abs(diff) + ' dia(s) antes do prazo (' + fmtDate(targetDate) + ').'
      }

      let bottleneck = ''
      if (maxEntry) {
        bottleneck = 'Etapa com mais tempo: ' + maxEntry[0] + ' (' + maxEntry[1] + ' dia(s)).'
        if (maxEntry[0] === 'In Review' || maxEntry[0] === 'Adjustment') {
          bottleneck += adjustCycles > 0
            ? ' Passou por ' + adjustCycles + ' ciclo(s) de ajuste, impactando o prazo.'
            : ' Revisao demorada pode ter impactado o prazo.'
        }
      }

      return [
        TRACKER_TAG,
        '## Task concluida - Relatorio Final',
        '',
        prazoLine,
        '',
        '---',
        '',
        '### Tempo por coluna',
        '',
        '| Coluna | Duracao |',
        '|---|---|',
        ...timeLines,
        '| Total | ' + totalDias + ' dia(s) |',
        '',
        '---',
        '',
        '### Analise',
        '',
        bottleneck,
        '',
        '---',
        '',
        '| Campo | Valor |',
        '|---|---|',
        '| Start date prevista | ' + fmtDate(startDate) + ' |',
        '| Target date | ' + fmtDate(targetDate) + ' |',
        '| Estimativa original | ' + estimateStr + ' |',
        '| Entregue em | ' + fmtDate(refDate) + ' |',
        '',
        '_Rastreio automatico de coluna._'
      ].join('\n')
    }

    return null
  }

  // ── EVENTO: issue fechada ────────────────────────────────────────
  if (context.eventName === 'issues' && context.payload.action === 'closed') {
    const issue       = context.payload.issue
    const issueNumber = issue.number

    const projectItem = await getProjectData(issueNumber)
    if (!projectItem) return

    const fields = projectItem.fieldValues.nodes

    const { data: comments } = await github.rest.issues.listComments({
      owner, repo, issue_number: issueNumber, per_page: 100
    })

    const trackerComments = comments
      .filter(c => c.body.includes(TRACKER_TAG))
      .sort((a, b) => new Date(a.created_at) - new Date(b.created_at))

    const body = buildComment('Done', fields, today, trackerComments, issue.closed_at)
    if (!body) return

    await github.rest.issues.createComment({ owner, repo, issue_number: issueNumber, body })
    console.log('Relatorio final adicionado na issue #' + issueNumber)
    return
  }

  // ── EVENTO: schedule — checa cards ativos ───────────────────────
  const query = `
    query($owner: String!, $number: Int!) {
      user(login: $owner) {
        projectV2(number: $number) {
          items(first: 100) {
            nodes {
              content {
                ... on Issue { number }
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

  const result = await github.graphql(query, { owner, number: PROJECT_NUMBER })
  const items  = result.user.projectV2.items.nodes

  for (const item of items) {
    if (!item.content?.number) continue

    const issueNumber = item.content.number
    const fields      = item.fieldValues.nodes
    const getSelect   = n => fields.find(f => f?.field?.name === n)?.name ?? null
    const status      = getSelect('Status')

    if (!status || status === 'Backlog' || status === 'Done') continue

    const { data: comments } = await github.rest.issues.listComments({
      owner, repo, issue_number: issueNumber, per_page: 100
    })

    const trackerComments = comments
      .filter(c => c.body.includes(TRACKER_TAG))
      .sort((a, b) => new Date(a.created_at) - new Date(b.created_at))

    // Verifica se o ultimo comentario de tracker ja e dessa coluna
    const lastTracker = trackerComments.at(-1)
    if (lastTracker) {
      const alreadyOnThisCol =
        (status === 'Ready'       && lastTracker.body.includes('pronta para iniciar')) ||
        (status === 'In Progress' && lastTracker.body.includes('Desenvolvimento iniciado')) ||
        (status === 'In Review'   && lastTracker.body.includes('para Review')) ||
        (status === 'Adjustment'  && lastTracker.body.includes('Voltou para Adjustment'))
      if (alreadyOnThisCol) continue
    }

    const body = buildComment(status, fields, today, trackerComments, null)
    if (!body) continue

    await github.rest.issues.createComment({ owner, repo, issue_number: issueNumber, body })
    console.log('Comentario [' + status + '] adicionado na issue #' + issueNumber)
    await new Promise(r => setTimeout(r, 500))
  }
}