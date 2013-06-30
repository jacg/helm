;;; helm-dabbrev.el --- Helm implementation of dabbrev.

;; Copyright (C) 2012 ~ 2013 Thierry Volpiatto <thierry.volpiatto@gmail.com>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'helm)
(require 'helm-elisp) ; For show-completion.

(defgroup helm-dabbrev nil
  "Dabbrev related Applications and libraries for Helm."
  :group 'helm)

(defcustom helm-dabbrev-always-search-all t
  "Always search in all buffers when non--nil."
  :group 'helm-dabbrev
  :type 'boolean)

(defcustom helm-dabbrev-max-length-result 10
  "Max length of candidates before searching in all buffers.
Have no effect when `helm-dabbrev-always-search-all' is non--nil."
  :group 'helm-dabbrev
  :type 'integer)

(defcustom helm-dabbrev-ignored-buffers-regexps
  '("\\*helm" "\\*Messages" "\\*Minibuf" "\\*Echo Area" "\\*Buffer List")
  "List of regexps matching names of buffers that helm-dabbrev should not check."
  :group 'helm-dabbrev
  :type '(repeat regexp))

(defcustom helm-dabbrev-major-mode-assoc
  '((emacs-lisp-mode . lisp-interaction-mode))
  "Major mode association alist to decide if helm-abbrev should check a buffer."
  :type '(alist :key-type symbol :value-type symbol)
  :group 'helm-abbrev)

(defcustom helm-dabbrev-lineno-around 12
  "Search first in this number of lines before an after point."
  :group 'helm-dabbrev
  :type 'integer)

(defvar helm-dabbrev-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map helm-map)
    (define-key map (kbd "M-/") 'helm-next-line)
    (define-key map (kbd "M-:") 'helm-previous-line)
    map))

(defun helm-dabbrev-buffer-list ()
  (loop for buf in (buffer-list)
        unless (loop for r in helm-dabbrev-ignored-buffers-regexps
                     thereis (string-match r (buffer-name buf)))
        collect buf))

(defun helm-dabbrev-same-major-mode-p (buf)
  (or (or (assoc major-mode helm-dabbrev-major-mode-assoc)
          (rassoc major-mode helm-dabbrev-major-mode-assoc))
      (eq major-mode (with-helm-current-buffer major-mode))))

(defun helm-dabbrev-collect (str limit ignore-case all)
  (let ((case-fold-search ignore-case)
        (search #'(lambda (pattern direction)
                    (declare (special result))
                    (while (case direction
                             (1   (search-forward pattern nil t))
                             (-1  (search-backward pattern nil t))
                             (2   (let ((pos
                                         (save-excursion
                                           (forward-line
                                            helm-dabbrev-lineno-around)
                                               (point))))
                                    (search-forward pattern pos t)))
                             (-2  (let ((pos
                                         (save-excursion
                                           (forward-line
                                            (- helm-dabbrev-lineno-around))
                                           (point))))
                                    (search-backward pattern pos t))))
                      (let ((match (substring-no-properties
                                    (thing-at-point 'symbol)))) 
                        (unless (or (string= str match) (member match result))
                          (push match result)))))))
    (loop with result
          for buf in (if all (helm-dabbrev-buffer-list)
                         (list (current-buffer)))
          do (with-current-buffer buf
               (when (helm-dabbrev-same-major-mode-p buf)
                 (save-excursion
                   (funcall search str -2))
                 (save-excursion
                   (funcall search str 2))
                 (save-excursion
                   (funcall search str -1))
                 (save-excursion
                   (funcall search str 1))))
          when (> (length result) limit) return (nreverse result)
          finally return (nreverse result))))

(defun helm-dabbrev-get-candidates (abbrev)
  (with-helm-current-buffer
    (let* ((dabbrev-get #'(lambda (str all-bufs)
                             (helm-dabbrev-collect
                              str helm-candidate-number-limit
                              nil all-bufs)))
           (lst (funcall dabbrev-get abbrev helm-dabbrev-always-search-all)))
      (if (and (not helm-dabbrev-always-search-all)
               (<= (length lst) helm-dabbrev-max-length-result))
          (funcall dabbrev-get abbrev 'all-bufs)
          lst))))

(defvar helm-source-dabbrev
  `((name . "Dabbrev Expand")
    (init . (lambda ()
              (helm-init-candidates-in-buffer
               'global
               (helm-dabbrev-get-candidates dabbrev))))
    (candidates-in-buffer)
    (keymap . ,helm-dabbrev-map)
    (action . (lambda (candidate)
                (let ((limits (with-helm-current-buffer
                                (bounds-of-thing-at-point 'symbol))))
                  (delete-region (car limits) (cdr limits))
                  (insert candidate))))))

;;;###autoload
(defun helm-dabbrev ()
  (interactive)
  (declare (special dabbrev))
  (let ((dabbrev (thing-at-point 'symbol))
        (limits (bounds-of-thing-at-point 'symbol))
        (helm-execute-action-at-once-if-one t)
        (helm-quit-if-no-candidate t))
    (with-helm-show-completion (car limits) (cdr limits)
      (helm :sources 'helm-source-dabbrev
            :buffer "*helm dabbrev*"
            :input (concat "^" dabbrev " ")
            :resume 'noresume))))

(provide 'helm-dabbrev)

;; Local Variables:
;; byte-compile-warnings: (not cl-functions obsolete)
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:

;;; helm-dabbrev ends here
