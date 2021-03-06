;;
;; This is my personal configuration for spacemacs
;;

(custom-set-variables
 '(c-basic-offset 4)
 '(c-offsets-alist
   (quote
    ((substatement-open . 0)
     (case-label . +)
     (innamespace . 0)
     (arglist-intro . +)
     (arglist-close . 0))))
 '(cua-mode t nil (cua-base))
 '(indent-tabs-mode nil)
 '(make-backup-files nil)
 '(org-directory "~/org")
 '(org-agenda-files '("~/org/"))
 '(org-default-notes-file "~/org/journal.org")
 '(org-capture-templates
   '(("t" "Todo" entry (file+headline "~/org/todo.org" "Tasks")
      "* TODO %?\n  %i\n  %a")
     ("g" "General" entry (file+headline "~/org/journal.org" "General")
      "* %?\n  Entered on %U\n  %i\n  %a")
     ("d" "Diary" entry (file+headline "~/org/journal.org" "Diary")
      "* %?\n  Entered on %U\n  %i\n  %a")
     ("p" "Programming" entry (file+headline "~/org/journal.org" "Programming")
      "* %?\n  Entered on %U\n  %i\n  %a")
     ("x" "Linux" entry (file+headline "~/org/journal.org" "Linux")
      "* %?\n  Entered on %U\n  %i\n  %a")
     ("k" "Networking" entry (file+headline "~/org/journal.org" "Network")
      "* %?\n  Entered on %U\n  %i\n  %a")
     ("b" "Database" entry (file+headline "~/org/journal.org" "Database")
      "* %?\n  Entered on %U\n  %i\n  %a")
     ("e" "Emacs" entry (file+headline "~/org/journal.org" "Emacs")
      "* %?\n  Entered on %U\n  %i\n  %a")
     ("a" "Graphics" entry (file+headline "~/org/journal.org" "Graphics")
      "* %?\n  Entered on %U\n  %i\n  %a")
     ("w" "Windows" entry (file+headline "~/org/journal.org" "Windows")
      "* %?\n  Entered on %U\n  %i\n  %a")
     ("m" "Mac" entry (file+headline "~/org/journal.org" "Mac")
      "* %?\n  Entered on %U\n  %i\n  %a")
     ("o" "Work" entry (file+headline "~/org/journal.org" "Work")
      "* %?\n  Entered on %U\n  %i\n  %a")
     ))
 )
