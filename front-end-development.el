;; front-end-development.el --- Front End Development File  -*- lexical-binding: t; -*-

;; Copyright (c) 2021 Marc-Antoine Loignon

;; Author: Marc-Antoine Loignon <developer@lognoz.org>
;; Homepage: https://github.com/lognoz/front-end-development
;; Keywords: front end development
;; Package-Version: 0.0.1
;; Package-Requires: ((emacs "25.1"))

;; This file is not part of GNU Emacs.

;;; License: GNU General Public License v3.0

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Provide Front End Development...
;; https://github.com/lognoz/front-end-development

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'json)


;;; Contextual constant.

(defgroup front-end-development nil
  "Provide more human-friendly front-end language development environment."
  :prefix "front-end-development"
  :group 'tools
  :link '(url-link "https://github.com/lognoz/front-end-development"))

(defvar front-end-development-root-directory nil
  "The directory of project root.")

(defvar front-end-development-scss-variables-path nil
  "The variables file located in scss directory.")

(defvar front-end-development-scss-variables nil
  "The configuration variables.")

(defvar front-end-development-version
  (eval-when-compile
    (with-temp-buffer
      (concat "0.0.1"
        (let ((dir (file-name-directory (or load-file-name
                                            byte-compile-current-file))))
          ;; Git repository or running in batch mode
          (if (and (file-exists-p (concat dir "/.git"))
                (ignore-errors
                  (zerop (call-process "git" nil '(t nil) nil
                                       "rev-parse"
                                       "--short" "HEAD"))))
            (progn
              (goto-char (point-min))
              (concat "-"
                (buffer-substring (point-min)
                  (line-end-position)))))))))
  "The current version of front end development.")


;;; Internal functions.

(cl-defun front-end-development--read (&key candidates input input-error regex prompt)
  "Read a string in the minibuffer, by defined PROMPT function.
INPUT is a string to prompt with; normally it ends in a colon and a space.
INPUT-ERROR is the error that will appear if the REGEX validation failed.
If CANDIDATES is non-nil, it will provide completion in `completing-read'."
  (let ((answer) (valid) (prompt-text) (prompt-error-text))
    (unless regex
      (setq regex ".+"))
    (unless prompt
      (setq prompt
        (if candidates 'completing-read 'read-string)))
    (unless input-error
      (setq input-error "require"))
    (setq prompt-text (concat input ": ")
          prompt-error-text
            (format "%s (%s): " input
                    (propertize input-error 'face
                                '((t :foreground "#ce5555")))))
    (while (not valid)
      (setq answer
        (string-trim
          (funcall prompt prompt-text
            (if (equal prompt 'completing-read)
                candidates
              answer))))
      (if (string-match-p regex answer)
          (setq valid t)
        (setq prompt-text prompt-error-text)))
    answer))

(defun front-end-development--json-content (path)
  "Return defined json content as alist located in PATH."
  (json-read-from-string
    (with-temp-buffer
      (insert-file-contents path)
      (buffer-substring-no-properties
        (point-min)
        (point-max)))))

(defun front-end-development--set-global ()
  "Set root directory and scss variables."
  (setq front-end-development-root-directory
    (locate-dominating-file
      (file-name-as-directory (file-name-directory buffer-file-name)) ".git"))
  (setq front-end-development-scss-variables-path
    (expand-file-name "scss/variables.json" front-end-development-root-directory))
  (unless (file-exists-p front-end-development-scss-variables-path)
    (user-error "Front-end-development: Unable to find %s" front-end-development-scss-variables-path))
  (setq front-end-development-scss-variables (front-end-development--json-content front-end-development-scss-variables-path)))

(defun front-end-development--scss-breakpoints-candidates (alist)
  "Return formatted ALIST for `completing-read' function."
  (let ((candidates))
    (dolist (parameters alist)
      (let* ((value (car parameters))
             (name (format "%s (%spx)" value (cdr parameters))))
        (setq candidates (push (cons name value) candidates))))
    candidates))

(defun front-end-development--scss-append-to-variables (value alist reference)
  "Insert new VALUE to its REFERENCE in given ALIST.
At the end of the function, the scss variables will be updated."
  (if alist
      (setf (cdr (assoc reference front-end-development-scss-variables))
        (push value alist))
    (setq front-end-development-scss-variables
      (push (cons reference (list value)) front-end-development-scss-variables)))
  (with-temp-buffer
    (insert (json-encode-alist front-end-development-scss-variables))
    (json-pretty-print-buffer)
    (write-region 1 (point-max) front-end-development-scss-variables-path)))


;;; External functions.

;;;###autoload
(define-minor-mode front-end-development-mode
  "Mode for front-end languages development."
  :lighter " front-end-development")

(defun front-end-development-scss-include-screen ()
  "Return mixin with predefined breakpoints variable."
  (front-end-development--set-global)
  (let ((breakpoints) (candidates) (answer) (screen) (size))
    (when (assoc 'breakpoints front-end-development-scss-variables)
      (setq breakpoints (cdr (assoc 'breakpoints front-end-development-scss-variables))
            candidates (front-end-development--scss-breakpoints-candidates
                         breakpoints)))
    (setq answer
      (front-end-development--read
        :input "Reference"
        :candidates candidates
        :prompt 'completing-read))
    (setq screen
      (if (assoc answer candidates)
          (cdr (assoc answer candidates))
        (setq size (front-end-development--read
                     :regex "^[0-9]+$"
                     :input "Size"
                     :input-error "number only"))
        (front-end-development--scss-append-to-variables
          (cons answer (string-to-number size)) breakpoints 'breakpoints)
        answer))
    (format "@include screen ('%s') {\n\t$0\n}" screen)))

;;;###autoload
(defun front-end-development-version ()
  "Print the current Front End Development version."
  (interactive)
  (message "Front End Development %s, Emacs %s, %s"
           front-end-development-version
           emacs-version
           system-type))


(provide 'front-end-development)

;;; front-end-development.el ends here
