#!/usr/bin/env python3
"""Build the af_heart distillation text list (docs/voice-model.md §24).

    python texts.py LIBRITTS_ROOT REPO_DATA_TTS OUT.tsv [--book N] [--conv N] [--held N] [--seed 0]

Rows: `id \t kind \t text`, kind in {book, conv, held}.
- book: LibriTTS-R normalized transcripts from train-clean-100/360 and train-other-500
  (never test-clean / dev-clean), 1..40 words.
- conv: templated conversational / robot lines (questions, short replies,
  backchannels, numbers/dates/units, names, exclamations, long sentences).
- held: 50 book + conv texts reserved for the af_heart held-out eval (never trained).
Any text that matches (case/punct-insensitive) a line of the eval sets
(wer_test_clean50.tsv, listen_v2_first.tsv) or any test-clean transcript is dropped.
"""
import argparse
import random
import re
from pathlib import Path


def norm(t):
    return re.sub(r"[^a-z0-9 ]", "", re.sub(r"\s+", " ", t.lower())).strip()


NAMES = ["Cam", "Maya", "Jordan", "Priya", "Luis", "Hannah", "Kenji", "Amara", "Olivia", "Noah", "Sofia",
         "Mateo", "Zoe", "Ethan", "Aisha", "Liam", "Chloe", "Diego", "Emma", "Ravi", "Grace", "Omar", "Ivy",
         "Felix", "Nora", "Theo", "Lena", "Marcus", "Yuki", "Sam", "Rose", "Frog", "Muni"]
PLACES = ["the kitchen", "the garage", "the front door", "the charging dock", "the living room", "the lab",
          "the workbench", "the back yard", "the hallway", "the office", "the couch", "the window", "the shelf"]
OBJECTS = ["the red cup", "your keys", "the screwdriver", "the blue box", "the remote", "a towel",
           "the skateboard", "the laptop", "the water bottle", "the headphones", "the charger", "the notebook",
           "the battery pack", "the tape measure", "the coffee mug", "your phone", "the cable"]
BACKCH = ["Mm-hm.", "Okay!", "Okay.", "Got it.", "Sure.", "Yeah.", "Yep!", "Uh-huh.", "Right.", "Oh!", "Hmm.",
          "Oh, nice.", "Totally.", "No problem.", "Of course!", "Sounds good.", "Wait, really?", "Huh.",
          "Ah, I see.", "Gotcha.", "Alright!", "One sec.", "Hold on.", "Sure thing!", "You bet.", "Nope.",
          "Hmm, let me think.", "Oh no!", "Wow!", "Yes!", "Perfect.", "Thanks!", "Thank you so much!",
          "Sorry about that.", "My bad.", "Hey!", "Hi there!", "Good morning!", "Good night.", "See you later!"]
EXCL = ["That's amazing!", "Whoa, look at that!", "I did it!", "Careful!", "Watch out!", "Nice catch!",
        "That was close!", "Oops!", "Ta-da!", "Let's go!", "No way!", "Ouch, that looked painful.",
        "Hooray!", "Oh wow, it actually worked!", "Yikes!", "Well, that didn't go as planned!"]
Q_T = ["Could you hand me {o}?", "Where did you leave {o}?", "Do you want me to bring {o} to {p}?",
       "Should I wait by {p}?", "{n}, are you ready?", "Is {n} coming over today?", "What time is it?",
       "How was your day, {n}?", "Did you mean {o}, or something else?", "Want to try that again?",
       "Can you hear me okay?", "Is this a good time to talk?", "Which one do you want, {n}?",
       "Have you seen {o} anywhere?", "Shall I turn the lights off in {p}?", "Are you sure about that?",
       "What should we do next?", "Do you need a hand with {o}?", "Is it too loud in {p}?",
       "Why don't we take a short break?", "How far is it to {p} from here?", "Who's at {p}?"]
R_T = ["Sure, I'll grab {o}.", "Okay, heading to {p} now.", "I put {o} next to {p}.", "Hi {n}, nice to see you!",
       "Sorry {n}, I didn't catch that.", "I'm almost at {p}.", "{o} is on the table by {p}.",
       "I'm not sure, but I'll check {p}.", "Okay {n}, give me one second.", "Got it, {o} it is.",
       "My battery is getting low, so I'll go to {p}.", "I can do that for you, {n}.",
       "Let me think about that for a moment.", "That makes sense to me.", "I'll be right there.",
       "Thanks, {n}! That really helps.", "I don't know yet, but I'll find out.", "Good idea, let's try it."]
UNITS = [("kilometers", "kilometer"), ("miles", "mile"), ("meters", "meter"), ("degrees", "degree"),
         ("percent", "percent"), ("kilograms", "kilogram"), ("minutes", "minute"), ("seconds", "second"),
         ("volts", "volt"), ("pounds", "pound")]
MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
          "November", "December"]
DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
LONG_T = ["When you get a chance, {n}, could you check whether {o} is still in {p}, because I looked there "
          "this morning and I'm fairly sure it wasn't where we left it?",
          "I walked from {p} to {p2} twice today, and both times I noticed that {o} had moved a little, "
          "which is either a mystery or someone is playing a joke on me.",
          "Before we start, let me explain the plan: first we clear {p}, then we bring {o} over, and "
          "finally we test everything slowly so nobody gets hurt.",
          "If the battery drops below {pct} percent, I'll stop what I'm doing, tell you, and head back "
          "to {p} to charge for about {m} minutes.",
          "{n} said the meeting is on {d}, {mo} {day}, at {h}:{mm}, but I'd double check the calendar "
          "because plans have been changing a lot this week."]


def ordinal(k):
    return f"{k}{'th' if 11 <= k % 100 <= 13 else {1: 'st', 2: 'nd', 3: 'rd'}.get(k % 10, 'th')}"


def conv_line(r):
    k = r.random()
    f = dict(n=r.choice(NAMES), o=r.choice(OBJECTS), p=r.choice(PLACES), p2=r.choice(PLACES),
             pct=r.randint(5, 30), m=r.randint(10, 90), d=r.choice(DAYS), mo=r.choice(MONTHS),
             day=ordinal(r.randint(1, 28)), h=r.randint(1, 12), mm=f"{r.choice([0, 5, 10, 15, 20, 30, 45, 50]):02d}")
    if k < 0.12:
        return r.choice(BACKCH)
    if k < 0.17:
        return r.choice(BACKCH) + " " + r.choice(R_T).format(**f)
    if k < 0.23:
        return r.choice(EXCL)
    if k < 0.45:
        return r.choice(Q_T).format(**f)
    if k < 0.65:
        return r.choice(R_T).format(**f)
    if k < 0.85:
        u = r.choice(UNITS)
        v = r.choice([r.randint(2, 99), r.randint(100, 9999), round(r.uniform(0.1, 99.9), 1)])
        t = r.choice([
            f"It's about {v} {u[0]} from here.", f"The temperature is {v} {u[0]} right now.",
            f"That weighs {v} {u[0]}.", f"We have {v} {u[0]} left.",
            f"Today is {f['d']}, {f['mo']} {f['day']}, {r.randint(1990, 2035)}.",
            f"Your appointment is at {f['h']}:{f['mm']} {r.choice(['AM', 'PM'])}.",
            f"The code is {r.randint(1000, 9999)}.", f"Call me at {r.randint(200, 999)}-{r.randint(1000, 9999)}.",
            f"It costs ${r.randint(1, 500)}.{r.randint(0, 99):02d}.", f"Room {r.randint(1, 450)}, on the {ordinal(r.randint(1, 12))} floor.",
            f"I counted {r.randint(2, 2000):,} steps since {f['d']}.", f"Battery at {r.randint(1, 100)}%.",
            f"In {r.randint(1500, 2030)}, {f['n']} was born on {f['mo']} {f['day']}."])
        return t
    return r.choice(LONG_T).format(**f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("tts_data")
    ap.add_argument("out")
    ap.add_argument("--book", type=int, default=52000)
    ap.add_argument("--conv", type=int, default=40000)
    ap.add_argument("--held", type=int, default=50)
    ap.add_argument("--seed", type=int, default=0)
    a = ap.parse_args()
    r = random.Random(a.seed)
    root = Path(a.root)
    ban = set()
    for f in ["wer_test_clean50.tsv", "listen_v2_first.tsv"]:
        for l in open(Path(a.tts_data) / f):
            p = l.rstrip("\n").split("\t")
            if len(p) > 1:
                ban.add(norm(p[1]))
    for p in (root / "test-clean").rglob("*.normalized.txt"):
        ban.add(norm(p.read_text()))
    book = []
    for split in ["train-clean-100", "train-clean-360", "train-other-500"]:
        for p in sorted((root / split).rglob("*.normalized.txt")):
            t = re.sub(r"\s+", " ", p.read_text()).strip()
            if 1 <= len(t.split()) <= 40 and norm(t) not in ban:
                book.append((p.name[: -len(".normalized.txt")], t))
    r.shuffle(book)
    seen, rows = set(ban), []

    def take(kind, uid, t):
        n = norm(t)
        if not n or n in seen:
            return False
        seen.add(n)
        rows.append((uid, kind, t))
        return True

    i = 0
    nb = 0
    while nb < a.book + a.held // 2 and i < len(book):
        uid, t = book[i]
        i += 1
        if take("held" if nb < a.held // 2 else "book", f"bk_{uid}", t):
            nb += 1
    nc, tries = 0, 0
    while nc < a.conv + a.held - a.held // 2 and tries < 50 * a.conv:
        tries += 1
        # backchannels repeat by design (a few copies, not thousands)
        t = conv_line(r)
        if take("held" if nc < a.held - a.held // 2 else "conv", f"cv_{nc:06d}", t):
            nc += 1
    # short canonical phrases allowed up to 8 renders each (kokoro is deterministic, so identical audio;
    # one copy each is enough for the corpus)
    with open(a.out, "w") as f:
        for uid, kind, t in rows:
            f.write(f"{uid}\t{kind}\t{t}\n")
    print(f"book {nb} conv {nc} rows {len(rows)} (book pool {len(book)})")


if __name__ == "__main__":
    main()
