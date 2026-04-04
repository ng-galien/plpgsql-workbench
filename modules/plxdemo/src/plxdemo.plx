module plxdemo
depends pgv

import pgv.t as t

include "./project.plx"
include "./project.spec.plx"
include "./task.plx"
include "./task.spec.plx"
include "./note.plx"
include "./note.spec.plx"

export plxdemo.health
export plxdemo.project
export plxdemo.task
export plxdemo.note

fn plxdemo.health() -> jsonb [stable]:
  return {name: "plxdemo", status: "ok", demo: "crud+validation+states+events"}

fn plxdemo.brand_payload() -> jsonb [stable]:
  return {entity: 'plxdemo', label: t('plxdemo.brand')}

test "health":
  assert plxdemo.health()->>'name' = 'plxdemo'
  assert plxdemo.health()->>'status' = 'ok'
  assert plxdemo.health()->>'demo' = 'crud+validation+states+events'

test "brand payload":
  p := plxdemo.brand_payload()
  assert p->>'entity' = 'plxdemo'
  assert p->>'label' = 'PLX Demo'

on plxdemo.project.activated(project_id):
  plxdemo.project_create_kickoff_task(project_id)
