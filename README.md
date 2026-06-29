# The Audit

> **Offline-first drone field operations, safety checklist, and audit trail application.**

## Overview

The Audit is a mobile application designed for drone (UAS) field teams to standardize and document every field operation. It replaces paper checklists, spreadsheets, and manual record keeping with a structured workflow that captures all operational data from planning through post-flight review.

The application is designed around three core goals:

* **Safety** — Ensure every flight follows a consistent checklist.
* **Traceability** — Produce a complete, timestamped audit trail.
* **Offline Reliability** — Continue operating without an internet connection.

---

# Project Goals

The application aims to:

* Standardize field operations
* Reduce missed safety checks
* Capture structured operational records
* Improve repeatability between field teams
* Maintain a searchable audit history
* Support future cloud synchronization
* Produce exportable mission reports

---

# Key Features

## User Authentication

* Secure user authentication
* Persistent login session
* Offline login after successful authentication
* User attribution for every record

---

## Field Session Management

Create and manage complete field sessions.

Each session contains:

* Date
* Site information
* GPS location
* Mission type
* Assigned team
* Vehicles
* Payloads
* Equipment checklist
* Multiple flights

---

## Pre-Field Checklist

Plan the day's activities before arriving on-site.

Includes:

* Mission planning
* Vehicle selection
* Payload assignment
* Team assignment
* Equipment checklist
* Objectives

---

## Preflight Checklist

Perform aircraft-specific safety inspections before each flight.

Supports:

* Vehicle selection
* Battery tracking
* Payload verification
* Telemetry checks
* Safety gates
* Go / No-Go decision
* Vehicle-specific checklists

---

## Post-Flight Notes

Capture operational results immediately after landing.

Includes:

* Mission outcome
* Battery status
* Flight observations
* Incident reporting
* Log storage location
* Additional notes

---

## Fleet Management

Maintain a registry of:

* Vehicles
* Payloads
* Batteries
* Checklist templates

---

## Records & History

Maintain a searchable history of:

* Sessions
* Flights
* Checklists
* Audit records
* Mission reports

---

## Export

Generate reports for completed operations.

Supported formats:

* PDF
* CSV

---

# Workflow

```text
Login

↓

Dashboard

↓

Start Field Session

↓

Pre-Field Checklist

↓

Create Flight

↓

Vehicle Selection

↓

Automatic Checklist

↓

Preflight Inspection

↓

Go / No-Go

↓

Flight

↓

Post-Flight Notes

↓

Another Flight?
      │
      ├── Yes → Repeat
      │
      └── No

↓

Close Session

↓

Export Report
```

---

# User Roles

## Operator

Responsible for:

* Running field sessions
* Completing checklists
* Recording flights

---

## Administrator

Responsible for:

* Fleet management
* Checklist management
* Reviewing operational records

---

# Core Concepts

## Field Session

Represents a complete field outing.

Contains one or more flights.

---

## Flight

Represents a single aircraft operation from takeoff to landing.

---

## Vehicle

A registered aircraft.

Different vehicle types load different checklist templates.

---

## Payload

Equipment carried by the aircraft.

Examples:

* RGB Camera
* Thermal Camera
* LiDAR
* Multispectral Camera

---

## Battery

Tracked as an individual asset.

May include:

* Asset ID
* Chemistry
* Cycle count
* Status

---

## Checklist Template

Defines the required inspection items for a vehicle type.

Templates are versioned.

---

# Functional Modules

* Authentication
* Dashboard
* Field Session Management
* Pre-Field Checklist
* Preflight Checklist
* Post-Flight Notes
* Fleet Management
* Records & History
* Export

---

# Non-Functional Requirements

* Offline-first operation
* Fast startup
* Automatic saving
* Reliable data persistence
* High outdoor usability
* Auditability
* Android tablet and phone support
* Extensible checklist templates

---

# Roadmap

Future enhancements may include:

* Cloud synchronization
* Team dashboards
* Maintenance tracking
* Telemetry import
* Weather integration
* Digital signatures
* Compliance reporting
* Fleet analytics
* Multi-platform support

---

# Documentation

Project documentation includes:

* Software Requirements Specification (SRS)
* Functional Requirements
* Vehicle Checklist Library
* Data Model
* User Workflow
* Future Roadmap

---

# Status

**Current Phase**

* Requirements gathering
* System design
* Project setup

Implementation is in progress.
