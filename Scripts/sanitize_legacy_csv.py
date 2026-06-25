import csv
import re
from collections import Counter
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Unbenannte Tabelle - Tabellenblatt1.csv"
SANITIZED = ROOT / "LegacyWorkouts_sanitized.csv"
REVIEW = ROOT / "LegacyWorkouts_review.csv"

MIN_COMPLETE_EXERCISES = 4
LOW_COUNT_THRESHOLD = 3
CURRENT_DATE = date(2026, 6, 17)

DATE_RE = re.compile(r"^\d{1,2}\.\d{1,2}\.\d{4}$")
SPACE_RE = re.compile(r"\s+")

DATE_CORRECTIONS = {
    (150, "30.05.3023"): "30.05.2023",
    (207, "12.08.2024"): "12.08.2023",
    (626, "26.10.2026"): "26.10.2025",
}

NOTE_ONLY_KEYWORDS = (
    "pause",
    "winterpause",
    "umstellung",
    "umgestellt",
    "dehnen",
    "walk in",
)


@dataclass
class RawRow:
    source_row: int
    cells: list[str]
    date_value: date | None
    date_note: str


@dataclass
class ParsedEntry:
    date: date
    exercise_name: str
    raw_exercise_name: str
    top_weight_kg: float | None
    top_reps: int | None
    notes: str
    source_row: str
    import_status: str


def clean_text(value: str) -> str:
    return SPACE_RE.sub(" ", value.replace("\n", " ")).strip()


def normalize(value: str) -> str:
    value = clean_text(value).lower()
    replacements = {
        "ä": "ae",
        "ö": "oe",
        "ü": "ue",
        "ß": "ss",
        "'": "",
        "´": "",
        "`": "",
    }
    for old, new in replacements.items():
        value = value.replace(old, new)
    return value


def parse_number(value: str) -> float | None:
    cleaned = clean_text(value).replace(",", ".")
    if not cleaned:
        return None

    try:
        return float(cleaned)
    except ValueError:
        return None


def parse_date(source_row: int, value: str) -> tuple[date | None, str]:
    cleaned = clean_text(value)
    if not DATE_RE.match(cleaned):
        return None, ""

    corrected = DATE_CORRECTIONS.get((source_row, cleaned), cleaned)
    parsed = datetime.strptime(corrected, "%d.%m.%Y").date()
    notes = []

    if corrected != cleaned:
        notes.append(f"Datum korrigiert von {cleaned} zu {corrected}")
    elif parsed > CURRENT_DATE:
        notes.append(f"Datum liegt nach {CURRENT_DATE.isoformat()}")

    return parsed, "; ".join(notes)


def canonical_exercise_name(raw_name: str) -> str:
    name = normalize(raw_name)

    if "bulgarian" in name:
        return "Bulgarian Squats"
    if name in {"squat", "squats"} or name.startswith("squats "):
        return "Kniebeuge"
    if "beinpresse" in name or "leg press" in name:
        return "Beinpresse"
    if "beinstrecker" in name or "leg extension" in name:
        return "Beinstrecker"
    if "beinbeuger" in name or "leg curl" in name:
        return "Beinbeuger"
    if "wadenpresse" in name:
        return "Wadenpresse"

    if "latziehen" in name or "latzug" in name:
        return "Latzug Kabel"
    if "klimm" in name:
        return "Klimmzüge"
    if "rueckenstrecker" in name or "unterer ruecken" in name:
        return "Rückenstrecker"
    if "rudern" in name:
        if "langhantel" in name:
            return "Langhantel Rudern"
        if "vorgebeugt" in name:
            return "Vorgebeugtes Rudern"
        return "Kabelrudern"

    if "schraegbank" in name and ("kurzhantel" in name or "kh" in name):
        return "Schrägbank Kurzhantel"
    if "schraeg" in name and "kurzhantel" in name:
        return "Schrägbank Kurzhantel"
    if "schraegbank" in name and "maschine" in name:
        return "Schrägbank Maschine"
    if "schraegbank" in name or "schraegbankdruecken" in name:
        return "Schrägbankdrücken"
    if "bankdruecken" in name and ("kurzhantel" in name or "kh" in name):
        return "Kurzhantel Bankdrücken"
    if "bankdruecken" in name:
        return "Bankdrücken"
    if "brustpresse" in name or "brudtpresse" in name or "chest press" in name or "lower chest" in name:
        return "Brustpresse"
    if "butterfly reverse" in name or "reverse butterfly" in name or "reverse butterfl" in name:
        return "Reverse Butterfly"
    if "butterfly" in name or "butterflies" in name or "pectoral" in name:
        return "Butterfly"

    if "military press" in name or ("schulterdruecken" in name and "langhantel" in name):
        return "Schulterdrücken Langhantel"
    if "schulterdruecken" in name and ("kurzhantel" in name or "kh" in name or " kurz" in name):
        return "Schulterdrücken Kurzhantel"
    if "schulterdruecken" in name and "maschine" in name:
        return "Schulterdrücken Maschine"
    if "schulterdruecken" in name:
        return "Schulterdrücken"
    if "seitheben vorgebeugt" in name:
        return "Seitheben Vorgebeugt"
    if "seitheben" in name:
        return "Seitheben"
    if "face pull" in name:
        return "Face Pull"
    if "rotator" in name or "rotstoren" in name:
        return "Rotatoren"

    if "trzieps" in name and "ueberkopf" in name:
        return "Trizepsdrücken Überkopf"
    if "trizeps" in name or "triceps" in name:
        if "kabel" in name:
            return "Trizeps Dips Kabelzug"
        if "dip" in name:
            return "Dips"
        return "Trizeps Dips Kabelzug"
    if "dips" in name and ("kabel" in name or "kabelzug" in name):
        return "Trizeps Dips Kabelzug"
    if name == "dips" or "dips" in name:
        return "Dips"
    if "preacher" in name or "scott" in name:
        return "Preacher Curls"
    if "bizeps" in name and "schraegbank" in name:
        return "Bizepscurls Schrägbank"
    if "bizeps" in name or "biceps" in name or "curls" in name or "sz stange" in name:
        if "maschine" in name:
            return "Bizepsmaschine"
        if "sz" in name or "stange" in name:
            return "Bizeps SZ"
        if "hammer" in name:
            return "Hammer Curls"
        return "Bizepscurls"

    if "bauchmaschine" in name or name == "bauch" or name.startswith("bauch "):
        return "Bauchmaschine"

    return clean_text(raw_name).title()


def is_note_only(raw_name: str) -> bool:
    name = normalize(raw_name)
    return any(keyword in name for keyword in NOTE_ONLY_KEYWORDS)


def first_date_in_row(source_row: int, cells: list[str]) -> tuple[date | None, str]:
    notes = []
    for cell in cells[3:5]:
        parsed, note = parse_date(source_row, cell)
        if parsed:
            if note:
                notes.append(note)
            return parsed, "; ".join(notes)
    return None, ""


def read_raw_rows() -> list[RawRow]:
    with SOURCE.open(encoding="utf-8-sig", newline="") as file:
        reader = csv.reader(file)
        next(reader)
        raw_rows = []
        for source_row, cells in enumerate(reader, start=2):
            padded = [clean_text(cell) for cell in (cells + ["", "", "", "", ""])[:5]]
            parsed_date, date_note = first_date_in_row(source_row, padded)
            raw_rows.append(RawRow(source_row, padded, parsed_date, date_note))
        return raw_rows


def group_workouts(raw_rows: list[RawRow]) -> list[tuple[date, list[RawRow], str]]:
    workouts = []
    pending_before_first_date = []
    current_date = None
    current_rows = []
    current_date_note = ""

    for raw in raw_rows:
        has_content = any(cell for cell in raw.cells)
        if not has_content:
            continue

        if raw.date_value:
            if current_date:
                workouts.append((current_date, current_rows, current_date_note))
            current_date = raw.date_value
            current_rows = []
            current_date_note = raw.date_note

            if pending_before_first_date:
                current_rows.extend(pending_before_first_date)
                pending_before_first_date = []

        if current_date:
            current_rows.append(raw)
        else:
            pending_before_first_date.append(raw)

    if current_date:
        workouts.append((current_date, current_rows, current_date_note))

    return workouts


def orientation_for_workout(rows: list[RawRow]) -> str:
    votes = Counter()
    for raw in rows:
        name = clean_text(raw.cells[0])
        if not name or is_note_only(name):
            continue

        first = parse_number(raw.cells[1])
        second = parse_number(raw.cells[2])
        if first is None or second is None:
            continue

        if first > 30 and second <= 30:
            votes["weight_reps"] += 2
        elif first <= 30 and second > 30:
            votes["reps_weight"] += 2
        elif "." in clean_text(raw.cells[1]).replace(",", ".") and second.is_integer():
            votes["weight_reps"] += 1

    return "weight_reps" if votes["weight_reps"] > votes["reps_weight"] else "reps_weight"


def format_number(value: float | None) -> str:
    if value is None:
        return ""
    if value.is_integer():
        return str(int(value))
    return str(value).rstrip("0").rstrip(".")


def estimated_bodyweight_kg(workout_date: date) -> float:
    if workout_date.year <= 2021:
        return 73
    if workout_date.year == 2022:
        year_start = date(2022, 1, 1)
        year_end = date(2022, 12, 31)
        progress = (workout_date - year_start).days / (year_end - year_start).days
        return round(73 + (80 - 73) * progress, 1)
    if workout_date.year <= 2024:
        return 80
    return 85


def parse_entry(workout_date: date, raw: RawRow, workout_orientation: str, date_note: str) -> ParsedEntry | None:
    raw_name = clean_text(raw.cells[0])
    if not raw_name:
        return None

    base_notes = []
    if raw.date_note:
        base_notes.append(raw.date_note)
    elif date_note and raw.date_value:
        base_notes.append(date_note)

    if is_note_only(raw_name):
        base_notes.append(raw_name)
        return ParsedEntry(
            date=workout_date,
            exercise_name="",
            raw_exercise_name=raw_name,
            top_weight_kg=None,
            top_reps=None,
            notes="; ".join(base_notes),
            source_row=str(raw.source_row),
            import_status="workout_note_only",
        )

    exercise_name = canonical_exercise_name(raw_name)
    first = parse_number(raw.cells[1])
    second = parse_number(raw.cells[2])
    notes = base_notes[:]
    status_flags = []

    for cell in raw.cells[1:5]:
        parsed_date, _ = parse_date(raw.source_row, cell)
        if cell and parsed_date is None and parse_number(cell) is None:
            notes.append(cell)

    if first is not None and second is not None:
        if first > 30 and second <= 30:
            weight = first
            reps = int(round(second))
            status_flags.append("swapped_weight_reps")
        elif first <= 30 and second > 30:
            reps = int(round(first))
            weight = second
        elif workout_orientation == "weight_reps":
            weight = first
            reps = int(round(second))
            status_flags.append("inferred_weight_reps")
        else:
            reps = int(round(first))
            weight = second
    elif first is not None:
        if first > 30:
            weight = first
            reps = None
            status_flags.append("needs_review_missing_reps")
        else:
            reps = int(round(first))
            weight = None
            status_flags.append("needs_review_missing_weight")
    elif second is not None:
        weight = second
        reps = None
        status_flags.append("needs_review_missing_reps")
    else:
        weight = None
        reps = None
        status_flags.append("needs_review_missing_values")

    if exercise_name == "Klimmzüge" and weight is None and reps is not None:
        weight = estimated_bodyweight_kg(workout_date)
        notes.append(f"Körpergewicht geschätzt mit {format_number(weight)} kg")
        status_flags = [
            flag
            for flag in status_flags
            if flag not in {"needs_review_missing_weight", "partial_entry"}
        ]
        status_flags.append("bodyweight_estimated")

    if weight is None or reps is None:
        status_flags.append("partial_entry")

    return ParsedEntry(
        date=workout_date,
        exercise_name=exercise_name,
        raw_exercise_name=raw_name,
        top_weight_kg=weight,
        top_reps=reps,
        notes="; ".join(dict.fromkeys(note for note in notes if note)),
        source_row=str(raw.source_row),
        import_status=";".join(status_flags) if status_flags else "ok",
    )


def valid_count(entries: list[ParsedEntry]) -> int:
    return sum(
        1
        for entry in entries
        if entry.exercise_name and entry.top_weight_kg is not None and entry.top_reps is not None
    )


def copy_entry(entry: ParsedEntry, target_date: date, source_workout_date: date) -> ParsedEntry:
    original_notes = [
        note.strip()
        for note in entry.notes.split(";")
        if note.strip()
        and not note.strip().startswith("Aus vorherigem vollständigem Workout")
        and not note.strip().startswith("Datum korrigiert")
    ]
    notes = [
        "; ".join(original_notes),
        f"Aus vorherigem vollständigem Workout vom {source_workout_date.isoformat()} übernommen",
    ]
    return ParsedEntry(
        date=target_date,
        exercise_name=entry.exercise_name,
        raw_exercise_name=entry.raw_exercise_name,
        top_weight_kg=entry.top_weight_kg,
        top_reps=entry.top_reps,
        notes="; ".join(note for note in notes if note),
        source_row=f"copied_from_{source_workout_date.isoformat()}",
        import_status="filled_from_previous_workout",
    )


def complete_incomplete_workout(
    workout_date: date,
    entries: list[ParsedEntry],
    last_complete: tuple[date, list[ParsedEntry]] | None,
) -> list[ParsedEntry]:
    current_valid = valid_count(entries)
    importable_entries = [entry for entry in entries if entry.exercise_name]
    note_entries = [entry for entry in entries if not entry.exercise_name]

    if current_valid >= MIN_COMPLETE_EXERCISES:
        return entries

    if current_valid == LOW_COUNT_THRESHOLD:
        for entry in importable_entries:
            if entry.import_status == "ok":
                entry.import_status = "low_exercise_count"
            else:
                entry.import_status += ";low_exercise_count"
        return note_entries + importable_entries

    if last_complete is None:
        for entry in importable_entries:
            entry.import_status += ";needs_review_no_previous_complete_workout"
        return note_entries + importable_entries

    source_date, source_entries = last_complete
    merged = [copy_entry(entry, workout_date, source_date) for entry in source_entries if entry.exercise_name]
    index_by_name = {entry.exercise_name: index for index, entry in enumerate(merged)}

    for entry in importable_entries:
        entry.import_status += ";actual_entry_in_incomplete_workout"
        entry.notes = "; ".join(
            note
            for note in [
                entry.notes,
                "Vorhandener Eintrag in unvollständigem Workout; restliche Übungen ergänzt",
            ]
            if note
        )
        if entry.exercise_name in index_by_name:
            merged[index_by_name[entry.exercise_name]] = entry
        else:
            merged.append(entry)

    return note_entries + merged


def append_note(existing_notes: str, new_note: str) -> str:
    notes = [note.strip() for note in existing_notes.split(";") if note.strip()]
    notes.append(new_note)
    return "; ".join(dict.fromkeys(notes))


def replace_status_flags(import_status: str, new_flags: list[str]) -> str:
    removed_flags = {
        "needs_review_missing_values",
        "needs_review_missing_weight",
        "needs_review_missing_reps",
        "partial_entry",
    }
    flags = [
        flag
        for flag in import_status.split(";")
        if flag and flag not in removed_flags
    ]
    flags.extend(new_flags)
    return ";".join(dict.fromkeys(flags)) if flags else "ok"


def fill_missing_values_from_previous_exercise(entries: list[ParsedEntry]) -> None:
    last_complete_by_exercise: dict[str, ParsedEntry] = {}

    for entry in entries:
        if not entry.exercise_name:
            continue

        has_weight = entry.top_weight_kg is not None
        has_reps = entry.top_reps is not None
        is_complete = has_weight and has_reps

        if is_complete:
            last_complete_by_exercise[entry.exercise_name] = entry
            continue

        previous = last_complete_by_exercise.get(entry.exercise_name)
        if previous is None:
            continue

        filled_flags = []
        filled_parts = []

        if not has_weight:
            entry.top_weight_kg = previous.top_weight_kg
            filled_parts.append("Gewicht")
            filled_flags.append("filled_missing_weight_from_previous_exercise")

        if not has_reps:
            entry.top_reps = previous.top_reps
            filled_parts.append("Reps")
            filled_flags.append("filled_missing_reps_from_previous_exercise")

        if filled_parts:
            entry.notes = append_note(
                entry.notes,
                (
                    f"Fehlende {'/'.join(filled_parts)} aus letztem vollständigem "
                    f"{entry.exercise_name}-Eintrag vom {previous.date.isoformat()} übernommen"
                ),
            )
            entry.import_status = replace_status_flags(entry.import_status, filled_flags)
            last_complete_by_exercise[entry.exercise_name] = entry


def fill_missing_values_from_next_exercise(entries: list[ParsedEntry]) -> None:
    next_complete_by_exercise: dict[str, ParsedEntry] = {}

    for entry in reversed(entries):
        if not entry.exercise_name:
            continue

        has_weight = entry.top_weight_kg is not None
        has_reps = entry.top_reps is not None
        is_complete = has_weight and has_reps

        if is_complete:
            next_complete_by_exercise[entry.exercise_name] = entry
            continue

        next_entry = next_complete_by_exercise.get(entry.exercise_name)
        if next_entry is None:
            continue

        filled_flags = []
        filled_parts = []

        if not has_weight:
            entry.top_weight_kg = next_entry.top_weight_kg
            filled_parts.append("Gewicht")
            filled_flags.append("filled_missing_weight_from_next_exercise")

        if not has_reps:
            entry.top_reps = next_entry.top_reps
            filled_parts.append("Reps")
            filled_flags.append("filled_missing_reps_from_next_exercise")

        if filled_parts:
            entry.notes = append_note(
                entry.notes,
                (
                    f"Fehlende {'/'.join(filled_parts)} aus erstem späterem vollständigem "
                    f"{entry.exercise_name}-Eintrag vom {next_entry.date.isoformat()} übernommen"
                ),
            )
            entry.import_status = replace_status_flags(entry.import_status, filled_flags)
            next_complete_by_exercise[entry.exercise_name] = entry


def write_csv(path: Path, rows: list[ParsedEntry]) -> None:
    headers = [
        "date",
        "exercise_name",
        "raw_exercise_name",
        "top_weight_kg",
        "top_reps",
        "notes",
        "source_row",
        "import_status",
    ]
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(headers)
        for entry in rows:
            writer.writerow(
                [
                    entry.date.isoformat(),
                    entry.exercise_name,
                    entry.raw_exercise_name,
                    format_number(entry.top_weight_kg),
                    entry.top_reps if entry.top_reps is not None else "",
                    entry.notes,
                    entry.source_row,
                    entry.import_status,
                ]
            )


def main() -> None:
    workouts = group_workouts(read_raw_rows())
    sanitized_rows = []
    last_complete = None

    for workout_date, raw_rows, date_note in workouts:
        orientation = orientation_for_workout(raw_rows)
        parsed_entries = [
            entry
            for raw in raw_rows
            if (entry := parse_entry(workout_date, raw, orientation, date_note)) is not None
        ]

        completed_entries = complete_incomplete_workout(workout_date, parsed_entries, last_complete)
        sanitized_rows.extend(completed_entries)

        if valid_count(completed_entries) >= MIN_COMPLETE_EXERCISES:
            last_complete = (
                workout_date,
                [entry for entry in completed_entries if entry.exercise_name and entry.import_status != "workout_note_only"],
            )

    fill_missing_values_from_previous_exercise(sanitized_rows)
    fill_missing_values_from_next_exercise(sanitized_rows)

    review_rows = [
        entry
        for entry in sanitized_rows
        if entry.import_status != "ok"
        or entry.notes
        or entry.top_weight_kg is None
        or entry.top_reps is None
        or not entry.exercise_name
    ]

    write_csv(SANITIZED, sanitized_rows)
    write_csv(REVIEW, review_rows)

    print(f"workouts={len(workouts)}")
    print(f"sanitized_rows={len(sanitized_rows)}")
    print(f"review_rows={len(review_rows)}")
    print(f"valid_import_rows={valid_count(sanitized_rows)}")
    print(f"sanitized={SANITIZED}")
    print(f"review={REVIEW}")


if __name__ == "__main__":
    main()
