# Changelog

## 1.0.5

- Ignore follow messages outside the Medina.
- Handle following before the current room is known without crashing or shifting the queued trajectory.
- Preserve candidate-set shape for look predictions.

## 1.0.4

- Remove automatic Room.Info, connection, and alleyway-detection debug messages.

## 1.0.3

- Rename the plugin to Being's Discworld Medina Mover.

## 1.0.2

- Validate against Mallard 0.27.0 (API 1.0).
- Add reproducible packaging and independent repository tests.
- Share module instances across commands, panels, and lifecycle callbacks.
- Preserve full map precision during sync, accept semantic versions, and apply received maps to current state.
