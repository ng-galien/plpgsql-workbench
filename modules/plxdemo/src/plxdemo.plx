module plxdemo
depends pgv

include "./task.plx"
include "./task.spec.plx"
include "./note.plx"
include "./note.spec.plx"

export plxdemo.health
export plxdemo.task
export plxdemo.note

fn plxdemo.health() -> jsonb [stable]:
  return {name: "plxdemo", status: "ok", demo: "crud"}

test "health":
  assert plxdemo.health()->>'name' = 'plxdemo'
  assert plxdemo.health()->>'status' = 'ok'
  assert plxdemo.health()->>'demo' = 'crud'
