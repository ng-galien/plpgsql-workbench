module plxdemo
depends pgv

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

test "health":
  assert plxdemo.health()->>'name' = 'plxdemo'
  assert plxdemo.health()->>'status' = 'ok'
  assert plxdemo.health()->>'demo' = 'crud+validation+states+events'

on plxdemo.project.activated(project_id):
  plxdemo.project_create_kickoff_task(project_id)
