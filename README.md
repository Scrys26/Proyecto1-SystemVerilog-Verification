# Proyecto 1 — Verificación Funcional en SystemVerilog

Ambiente de verificación funcional desarrollado para el Proyecto 1 del curso
**Verificación Funcional de Circuitos Integrados**.

El proyecto consiste en desarrollar un ambiente de pruebas en SystemVerilog
para verificar el funcionamiento de un DUT correspondiente a un sistema de bus
con múltiples terminales.

---

## Equipo

Proyecto desarrollado por:

- Integrante 1 — `Campos Herrera	Josue Andres`
- Integrante 2 — `Fernández Aguilar Randy Steve`
- Integrante 3 — `Vargas Arias Jesus David`

---

## Objetivo

Diseñar e implementar un ambiente de verificación capaz de generar,
controlar, observar y comprobar transacciones realizadas a través del DUT.

El ambiente deberá permitir la generación de estímulos aleatorios controlados
y la detección de comportamientos incorrectos durante la simulación.

---

## DUT

El DUT corresponde a un sistema de bus parametrizable.

Los archivos base proporcionados por el profesor se encuentran en:

```text
DUT/Referencias/
├── Library.sv
└── fifo.sv
