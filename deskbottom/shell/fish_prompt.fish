# Raddix — the RootCellar fish prompt.
# Spec: docs/BRANDING.md. Two lines: crown + neck + info, then the creature
# and its tail. On failure the neck mirrors, the curls flatten, the face
# deflates, and the tail stops wagging.

function fish_prompt
    set -l last_status $status
    set -l purple A06BE0
    set -l dblue 5277C3
    set -l lblue 7EBAE5
    set -l white F5F3F1
    set -l dim 6F6785

    set -l face
    if test $last_status -eq 0
        set -l faces "'.'" "' '" "'‿'" "°.°" "•‿•" "˘.˘"
        set face $faces[(random 1 (count $faces))]
    else
        set face "._."
    end

    set -l branch (git branch --show-current 2>/dev/null)

    # Line 1: crown, neck, info
    if test $last_status -eq 0
        set_color $dblue; printf '  \\'
        set_color $lblue; printf '|'
        set_color $dblue; printf '╭- '
    else
        set_color $dim; printf '  ╮'
        set_color $lblue; printf '|'
        set_color $dblue; printf '╭- '
    end
    set_color $white; printf '%s@' $USER
    set_color $lblue; printf '%s' (hostname)
    set_color $lblue; printf '  %s' (prompt_pwd)
    if test -n "$branch"
        set_color $purple; printf '  %s' $branch
    end
    if test $last_status -ne 0
        set_color $purple; printf '  ✗ %d' $last_status
    end
    echo

    # Line 2: the creature and its tail
    if test $last_status -eq 0
        set_color $lblue; printf ' ⌣'
        set_color $purple; printf '⟨'
        set_color $white; printf '%s' $face
        set_color $purple; printf '⟩'
        set_color $lblue; printf '⌣'
        set_color $purple; printf '≪'
        set_color $lblue; printf '~ '
    else
        set_color $dim; printf '_⟨'
        set_color $white; printf '%s' $face
        set_color $dim; printf '⟩_≪~ '
    end
    set_color normal
end
