import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import vm from "node:vm"

// Exercise the production controller without needing a browser or Stimulus runtime.
const source = readFileSync(new URL("../../app/javascript/controllers/keyboard_controller.js", import.meta.url), "utf8")
function loadController(globals = {}) {
  return vm.runInNewContext(
    source.replace('import { Controller } from "@hotwired/stimulus"', "class Controller {}")
      .replace("export default class", "class KeyboardController") + "\nKeyboardController",
    globals
  )
}
const KeyboardController = loadController()

function setup(value = "", disabled = false) {
  const controller = new KeyboardController()
  controller.inputTarget = { value, disabled }
  controller.currentScore = 501
  controller.getMaxPossible = () => 180
  controller.resetScoreCardPreview = () => {}
  const submitted = []
  controller.submitThrow = (...args) => submitted.push(args)
  return { controller, submitted }
}

for (const value of ["", "   "]) {
  test(`empty Submit records zero (${JSON.stringify(value)})`, () => {
    const { controller, submitted } = setup(value)
    controller.submitInput()
    assert.deepEqual(submitted, [[null, null, 0]])
  })
}

test("empty Enter prevents default and records zero", () => {
  const { controller, submitted } = setup()
  let prevented = false
  controller.handle({ key: "Enter", preventDefault: () => { prevented = true } })
  assert.equal(prevented, true)
  assert.deepEqual(submitted, [[null, null, 0]])
})

for (const value of ["0", "60", "180"]) {
  test(`numeric submission remains unchanged (${value})`, () => {
    const { controller, submitted } = setup(value)
    controller.handle({ key: "Enter", preventDefault() {} })
    assert.deepEqual(submitted, [[null, null, Number(value)]])
  })
}

for (const value of ["", "60"]) {
  test(`disabled input does not submit (${JSON.stringify(value)})`, () => {
    const { controller, submitted } = setup(value, true)
    controller.submitInput()
    controller.handle({ key: "Enter", preventDefault() { assert.fail("disabled Enter") } })
    assert.deepEqual(submitted, [])
  })
}

for (const botTurn of [true, false]) {
  test(`undo with disabled score input during bot turn=${botTurn}`, async () => {
    const requests = []
    const streams = []
    const Controller = loadController({
      document: {
        querySelector: (selector) => selector.startsWith("meta") ? { content: "csrf" } : null,
        getElementById: () => ({ action: "/turns/tu_bot/throws" })
      },
      fetch: async (url, options) => {
        requests.push({ url, options })
        return { ok: true, text: async () => "updated human turn" }
      },
      Turbo: { renderStreamMessage: (html) => streams.push(html) }
    })
    const controller = new Controller()
    controller.inputTarget = { disabled: true }
    controller.botTurnValue = botTurn

    await controller.undoLastThrow()

    assert.equal(requests.length, botTurn ? 1 : 0)
    if (botTurn) {
      assert.equal(requests[0].url, "/turns/tu_bot/throws/last")
      assert.equal(requests[0].options.method, "DELETE")
      assert.equal(requests[0].options.headers["X-Undo-Mode"], "total")
      assert.deepEqual(streams, ["updated human turn"])
    }
  })
}

test("other keys do not submit", () => {
  const { controller, submitted } = setup()
  controller.handle({ key: "Escape", preventDefault() { assert.fail("other key") } })
  assert.deepEqual(submitted, [])
})

for (const value of ["abc", "-1", "181", "502"]) {
  test(`invalid total is still rejected (${value})`, () => {
    const { controller, submitted } = setup(value)
    controller.submitInput()
    assert.deepEqual(submitted, [])
  })
}
