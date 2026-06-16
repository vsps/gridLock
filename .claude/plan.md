I want to rework the app.
write a plan to .claude/plan.md

### CLEANUP:

remove the recording and sample playback functionality completley.

From user testing I found a key is likely to be held down for a long time, and multiple keys at once leading to too many sound triggers and crashes - limit to 6 voice polyphony.

### BIG CHANGES:

change the layout of the keyboard from a grid to a harmonic table (hex grid layout, each button can be a circle)

Settings should have a single scale setting to zoom out but the center should be middle C.

### NOTE TRIGGERING:

There should be multiple modes of triggering a button:
- tap (existing)
- finger slide (existin)
- clock trigger (new)

I want an underlying clock to be running (default to 128bpm but adjustable in settings).
All tap triggers should be quantised to nearest 1/16th note meaning that pressing a button should queue the trigger to nearest 1/16th rather than instant. subsequent notes triggered by slide should be triggered free of quantisation.
Held notes should re-trigger every 1/2 bar .


### AUDIO EFFECT LAYERS:

- Lower notes are harder to hear so add another harmony to the synth sound and add an overdrive effect that increases the further away from the middle C the note is.
- For each bar the note is held increase the echo slightly.

### VISUAL EFFECTS:

- remove the ripple effect from the keyboard but keep the propagation, increase it's radius to 2 neighbors and increase the fade time to 2s.
