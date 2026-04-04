module hr

import jsonb_build_object as obj
import jsonb_build_array as arr

include "./balance.plx"
include "./employee.plx"
include "./leave.plx"
include "./timesheet.plx"
include "./helpers.plx"
include "./employee.spec.plx"
include "./leave.spec.plx"

export hr.employee
export hr.leave_request
export hr.timesheet

fn hr.brand() -> text [stable]:
  return i18n.t('hr.brand')

fn hr.nav_items() -> jsonb [stable]:
  return arr(
    obj('href', '/', 'label', i18n.t('hr.nav_employees'), 'icon', 'users', 'entity', 'employee'),
    obj('href', '/absences', 'label', i18n.t('hr.nav_absences'), 'icon', 'calendar', 'entity', 'leave_request'),
    obj('href', '/timesheets', 'label', i18n.t('hr.nav_timesheets'), 'icon', 'clock', 'entity', 'timesheet')
  )
