module.exports = async ({ github, context, core }) => {
  const payload = context.payload
  const item = payload.projects_v2_item

  const changedField = payload.changes?.field_value?.field_name
  if (changedField !== 'Status') return

  const fromStatus = payload.changes?.field_value?.before?.name ?? 'Desconhecido'
  const toStatus   = payload.changes?.field_value?.after?.name  ?? 'Desconhecido'

  console.log(`Transição: ${fromStatus} → ${toStatus}`)

  const query = `
    query($nodeId: ID!) {
      node(id: $nodeId) {
        ... on ProjectV2Item {
          content {
            ... on Issue {
              number
              title
              repository {
                owner { login }
                name
              }
            }
          }
          fieldValues(first: 30) {
            nodes {
              ... on ProjectV2ItemFieldDateValue {
                date
                field { ... on ProjectV2Field { name } }
              }
              ... on ProjectV2ItemFieldNumberValue {
                number
                field { ... on ProjectV2Field { name } }
              }
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field { ... on ProjectV2SingleSelectField { name } }
              }
            }
          }
        }
      }
    }
  `

  const result   = await github.graphql(query, { nodeId: item.node_id })
  const itemData = result.node
  const content  = itemData?.content
  if (!content?.number) return

  const issueNumber = content.number
  const owner       = content.repository.owner.login
  const repo        = content.repository.name

  const fields    = itemData.fieldValues.nodes
  const getDate   = name => fields.find(n => n?.field?.name === name)?.date   ?? null
  const getNumber = name => fields.find(n => n?.field?.name === name)?.number ?? null

  const startDate  = getDate('Start date')
  const targetDate = getDate('Target date')
  const estimate   = getNumber('Estimate')

  const fmtDate = iso => iso
    ? new Date(iso + 'T00:00:00').toLocaleDateString('pt-BR')
    : '—'

  const daysBetween = (isoA, isoB) => {
    const a = new Date(isoA.includes('T') ? isoA : isoA + 'T00:00:00')
    const b = new Date(isoB.includes('T') ? isoB : isoB + 'T00:00:00')
    return Math.round((b - a) / (1000 * 60 * 60 * 24))
  }

  const today = new Date().toISOString().split('T')[0]

  const { data: allComments } = await github.rest.issues.listComments({
    owner, repo, issue_number: issueNumber, per_page: 100
  })

  const trackerTag      = '<!-- column-tracker -->'
  const trackerComments = allComments
    .filter(c => c.body.includes(trackerTag))
    .sort((a, b) => new Date(a.created_at) - new Date(b.created_at))

  const lastTrackerComment = trackerComments.at(-1)
  const lastCommentDate    = lastTrackerComment
    ? lastTrackerComment.created_at.split('T')[0]
    : today

  const daysInPrevColumn = daysBetween(lastCommentDate, today)

  let body = ''

  if (toStatus === 'Ready') {
    body = [
      '<!-- column-tracker -->',
      '## Tarefa pronta para iniciar',
      '',
      '| Campo | Valor |',
      '|---|---|',
      '| Start date prevista | ' + fmtDate(startDate) + ' |',
      '| Target date | ' + fmtDate(targetDate) + ' |',
      '| Estimativa | ' + (estimate != null ? estimate + ' horas' : '—') + ' |',
      '',
      '> Task movida para **Ready** — aguardando início do desenvolvimento.',
      '',
      '_Rastreio automático de coluna._'
    ].join('\n')
  }

  else if (toStatus === 'In Progress') {
    const prazoTotal = (startDate && targetDate)
      ? daysBetween(startDate, targetDate) + ' dias'
      : '—'

    body = [
      '<!-- column-tracker -->',
      '## Desenvolvimento iniciado',
      '',
      '| Campo | Valor |',
      '|---|---|',
      '| Iniciado em | ' + fmtDate(today) + ' |',
      '| Start date prevista | ' + fmtDate(startDate) + ' |',
      '| Target date | ' + fmtDate(targetDate) + ' |',
      '| Estimativa | ' + (estimate != null ? estimate + ' horas' : '—') + ' |',
      '| Janela total de prazo | ' + prazoTotal + ' |',
      '| Tempo em ' + fromStatus + ' | ' + daysInPrevColumn + ' dia(s) |',
      '',
      '_Rastreio automático de coluna._'
    ].join('\n')
  }

  else if (toStatus === 'In Review') {
    const isFromAdjustment = fromStatus === 'Adjustment'
    const label = isFromAdjustment ? 'Retornou para Review após ajuste' : 'Enviado para Review'

    let prazoLinha = ''
    if (targetDate) {
      const diffToTarget = daysBetween(today, targetDate)
      if (diffToTarget >= 0) {
        prazoLinha = '| Dias restantes até o prazo | ' + diffToTarget + ' dia(s) |'
      } else {
        prazoLinha = '| Atraso acumulado até agora | ' + Math.abs(diffToTarget) + ' dia(s) |'
      }
    }

    body = [
      '<!-- column-tracker -->',
      '## ' + label,
      '',
      '| Campo | Valor |',
      '|---|---|',
      '| Data | ' + fmtDate(today) + ' |',
      '| Target date | ' + fmtDate(targetDate) + ' |',
      '| Tempo em ' + fromStatus + ' | ' + daysInPrevColumn + ' dia(s) |',
      prazoLinha,
      '',
      '_Rastreio automático de coluna._'
    ].join('\n')
  }

  else if (toStatus === 'Adjustment') {
    let prazoMsg = '—'
    if (targetDate) {
      const diffToTarget = daysBetween(today, targetDate)
      if (diffToTarget > 0) {
        prazoMsg = 'Ainda dentro do prazo, mas restam apenas ' + diffToTarget + ' dia(s)'
      } else if (diffToTarget === 0) {
        prazoMsg = 'Prazo é hoje!'
      } else {
        prazoMsg = 'Ja esta ' + Math.abs(diffToTarget) + ' dia(s) atrasado'
      }
    }

    body = [
      '<!-- column-tracker -->',
      '## Voltou para Adjustment',
      '',
      '| Campo | Valor |',
      '|---|---|',
      '| Data | ' + fmtDate(today) + ' |',
      '| Target date | ' + fmtDate(targetDate) + ' |',
      '| Tempo em ' + fromStatus + ' | ' + daysInPrevColumn + ' dia(s) |',
      '| Situacao do prazo | ' + prazoMsg + ' |',
      '',
      '### Motivo do ajuste:',
      '-',
      '',
      '_Rastreio automático de coluna._'
    ].join('\n')
  }

  else if (toStatus === 'Done') {
    const colTimes = {}
    for (const c of trackerComments) {
      let col = ''
      if (c.body.includes('pronta para iniciar'))      col = 'Ready'
      else if (c.body.includes('Desenvolvimento iniciado')) col = 'In Progress'
      else if (c.body.includes('Review'))               col = 'In Review'
      else if (c.body.includes('Adjustment'))           col = 'Adjustment'
      if (!col) continue

      const idx      = trackerComments.indexOf(c)
      const nextDate = trackerComments[idx + 1]?.created_at ?? new Date().toISOString()
      const dur      = daysBetween(c.created_at.split('T')[0], nextDate.split('T')[0])
      colTimes[col]  = (colTimes[col] ?? 0) + dur
    }

    if (fromStatus && !colTimes[fromStatus]) colTimes[fromStatus] = daysInPrevColumn

    const maxCol = Object.entries(colTimes).sort((a, b) => b[1] - a[1])[0]

    const adjustmentCycles = trackerComments.filter(c =>
      c.body.includes('Voltou para Adjustment')
    ).length

    let prazoAnalysis = ''
    if (targetDate) {
      const diff = daysBetween(targetDate, today)
      if (diff > 0) {
        prazoAnalysis = 'Entrega atrasada — prazo era ' + fmtDate(targetDate) + ', atraso de ' + diff + ' dia(s)'
      } else if (diff === 0) {
        prazoAnalysis = 'Entrega no prazo — entregue exatamente em ' + fmtDate(targetDate)
      } else {
        prazoAnalysis = 'Entrega adiantada — ' + Math.abs(diff) + ' dia(s) antes do prazo (' + fmtDate(targetDate) + ')'
      }
    }

    const colOrder = ['Ready', 'In Progress', 'In Review', 'Adjustment']
    const timeLines = colOrder
      .filter(col => colTimes[col] != null)
      .map(col => {
        const isMax = maxCol && maxCol[0] === col
        return '| ' + (isMax ? '' : '') + col + ' | ' + colTimes[col] + ' dia(s)' + (isMax ? ' — mais tempo aqui' : '') + ' |'
      })

    const totalDias = Object.values(colTimes).reduce((a, b) => a + b, 0)

    let bottleneck = ''
    if (maxCol) {
      if (maxCol[0] === 'In Review' || maxCol[0] === 'Adjustment') {
        bottleneck = 'Gargalo em ' + maxCol[0] + ' (' + maxCol[1] + ' dias).' +
          (adjustmentCycles > 0 ? ' Passou por ' + adjustmentCycles + ' ciclo(s) de ajuste.' : '')
      } else {
        bottleneck = 'Etapa que mais consumiu tempo: ' + maxCol[0] + ' (' + maxCol[1] + ' dias).'
      }
    }

    body = [
      '<!-- column-tracker -->',
      '## Task concluida — Relatorio Final',
      '',
      prazoAnalysis,
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
      adjustmentCycles > 0 ? 'A task passou ' + adjustmentCycles + 'x pelo ciclo Adjustment → Review.' : '',
      '',
      '---',
      '',
      '| Campo | Valor |',
      '|---|---|',
      '| Start date prevista | ' + fmtDate(startDate) + ' |',
      '| Target date | ' + fmtDate(targetDate) + ' |',
      '| Estimativa original | ' + (estimate != null ? estimate + ' horas' : '—') + ' |',
      '| Entregue em | ' + fmtDate(today) + ' |',
      '',
      '_Rastreio automático de coluna._'
    ].join('\n')
  }

  if (!body) return

  await github.rest.issues.createComment({
    owner, repo,
    issue_number: issueNumber,
    body
  })

  console.log('Comentário adicionado na issue #' + issueNumber + ': ' + fromStatus + ' → ' + toStatus)
}