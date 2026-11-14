/*
  Navio form guidance for the Keycloak login theme.

  - Tells people what each sign-up field needs before they submit, including a
    live password checklist that mirrors the realm password policy.
  - Clears a field's red error state as soon as its value becomes valid.
    Keycloak marks a rejected field with aria-invalid="true" and pf-m-error and
    never removes them, so a corrected field used to stay red.
  - Checks the form before it is sent. Keycloak empties both password fields
    whenever it rejects a registration, so catching a mistake here saves people
    from typing the password twice again.

  Keycloak still validates everything on the server; this script only explains
  the rules sooner. It loads as a classic script in <head>, so it waits for the
  DOM. Wording comes from #navio-field-hints (template.ftl), which reads
  messages/messages_en.properties.
*/

// Mirrors passwordPolicy in .deploy/scripts/deploy.sh and navio-realm.json:
// length(8) and regexPattern((?=.*[a-z])(?=.*[0-9])(?=.*[^a-z0-9]).*) and
// notUsername and notEmail. Change all three together.
var NAVIO_PASSWORD_MIN_LENGTH = 8;

function evaluateNavioPassword(password, email) {
  var value = typeof password === "string" ? password : "";
  var address = typeof email === "string" ? email.trim() : "";
  var rules = [
    { key: "length", met: value.length >= NAVIO_PASSWORD_MIN_LENGTH },
    { key: "lower", met: /[a-z]/.test(value) },
    { key: "number", met: /[0-9]/.test(value) },
    { key: "upperOrSymbol", met: /[^a-z0-9]/.test(value) },
  ];
  if (email !== undefined) {
    rules.push({
      key: "notEmail",
      met: value.length > 0 && (address === "" || value.toLowerCase() !== address.toLowerCase()),
    });
  }
  return rules;
}

function isNavioEmail(value) {
  // Deliberately looser than Keycloak's validator: it must never block an
  // address the server would accept. The server still has the final say.
  return /^[^\s@]+@[^\s@]+$/.test(value.trim());
}

(function () {
  if (typeof document === "undefined") {
    return;
  }

  var ICON_UNMET =
    '<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><circle cx="8" cy="8" r="6.25" fill="none" stroke="currentColor" stroke-width="1.5"/></svg>';
  var ICON_MET =
    '<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><circle cx="8" cy="8" r="7" fill="currentColor"/><path d="M4.75 8.25l2.1 2.1 4.4-4.6" fill="none" stroke="var(--navio-surface)" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  function init() {
    var hintsSource = document.getElementById("navio-field-hints");
    if (!hintsSource) {
      return;
    }
    var text = hintsSource.dataset;

    var email = document.getElementById("email");
    var firstName = document.getElementById("firstName");
    var lastName = document.getElementById("lastName");
    var confirm = document.getElementById("password-confirm");
    // Only forms that set a password have a confirmation field; the login form
    // also has #password and must not show the rules.
    var password = confirm
      ? document.getElementById("password-new") || document.getElementById("password")
      : null;
    var form = (password || email || firstName || lastName || { form: null }).form;

    if (!form || form.id === "kc-form-login") {
      return;
    }

    var fields = [];

    function groupOf(input) {
      return input.closest(".pf-v5-c-form__group");
    }

    function isRequired(input) {
      var group = groupOf(input);
      return Boolean(group && group.querySelector(".pf-v5-c-form__label-required"));
    }

    function errorContainerFor(input) {
      var id = "input-error-container-" + input.id;
      var container = document.getElementById(id);
      if (!container) {
        container = document.createElement("div");
        container.id = id;
        groupOf(input).appendChild(container);
      }
      return container;
    }

    function describe(input, ids) {
      var current = (input.getAttribute("aria-describedby") || "").split(/\s+/);
      ids.forEach(function (id) {
        if (current.indexOf(id) === -1) {
          current.push(id);
        }
      });
      input.setAttribute("aria-describedby", current.filter(Boolean).join(" "));
    }

    function placeBeforeErrors(input, node) {
      var container = errorContainerFor(input);
      container.parentNode.insertBefore(node, container);
      describe(input, [node.id, container.id]);
    }

    function addHint(input, message) {
      if (!input || !message) {
        return null;
      }
      var hint = document.createElement("p");
      hint.className = "navio-hint";
      hint.id = input.id + "-hint";
      hint.textContent = message;
      placeBeforeErrors(input, hint);
      return hint;
    }

    function setError(input, message) {
      input.setAttribute("aria-invalid", "true");
      var wrapper = input.closest(".pf-v5-c-form-control");
      if (wrapper) {
        wrapper.classList.add("pf-m-error");
      }
      var container = errorContainerFor(input);
      var outer = document.createElement("div");
      outer.className = "pf-v5-c-form__helper-text";
      var helper = document.createElement("div");
      helper.className = "pf-v5-c-helper-text";
      var item = document.createElement("div");
      item.className = "pf-v5-c-helper-text__item pf-m-error";
      item.id = "input-error-" + input.id;
      var line = document.createElement("span");
      line.className = "pf-v5-c-helper-text__item-text pf-m-error kc-feedback-text";
      line.textContent = message;
      item.appendChild(line);
      helper.appendChild(item);
      outer.appendChild(helper);
      container.replaceChildren(outer);
    }

    function clearError(input) {
      input.setAttribute("aria-invalid", "false");
      var wrapper = input.closest(".pf-v5-c-form-control");
      if (wrapper) {
        wrapper.classList.remove("pf-m-error");
      }
      errorContainerFor(input).replaceChildren();
    }

    function isMarkedInvalid(input) {
      return input.getAttribute("aria-invalid") === "true";
    }

    // Returns the message to show, or "" when the value is acceptable.
    function problemWith(input) {
      var value = input.value;
      if (input === password) {
        if (value === "" && isRequired(input)) {
          return text.errorRequired;
        }
        var unmet = evaluateNavioPassword(value, email ? email.value : undefined).some(function (rule) {
          return !rule.met;
        });
        return unmet ? text.errorPassword : "";
      }
      if (input === confirm) {
        if (value === "") {
          return text.errorRequired;
        }
        return password && value !== password.value ? text.errorConfirm : "";
      }
      if (value.trim() === "") {
        return isRequired(input) ? text.errorRequired : "";
      }
      if (input === email && !isNavioEmail(value)) {
        return text.errorEmail;
      }
      return "";
    }

    // While someone edits a rejected field, drop the red state the moment the
    // value is valid. It never turns a field red mid-typing.
    function refreshError(input) {
      if (isMarkedInvalid(input) && problemWith(input) === "") {
        clearError(input);
      }
    }

    [email, firstName, lastName].forEach(function (input) {
      if (!input) {
        return;
      }
      fields.push(input);
      var key = input === email ? "hintEmail" : input === firstName ? "hintFirstName" : "hintLastName";
      addHint(input, text[key]);
      input.addEventListener("input", function () {
        refreshError(input);
        if (input === email && password) {
          renderRules();
          refreshError(password);
        }
      });
    });

    var ruleItems = {};
    var rulesStatus = null;
    var announceTimer = 0;

    function renderRules() {
      if (!password) {
        return;
      }
      var results = evaluateNavioPassword(password.value, email ? email.value : undefined);
      var metCount = 0;
      results.forEach(function (rule) {
        var item = ruleItems[rule.key];
        if (!item) {
          return;
        }
        if (rule.met) {
          metCount += 1;
        }
        if (item.dataset.met !== String(rule.met)) {
          item.dataset.met = String(rule.met);
          item.querySelector(".navio-rule__icon").innerHTML = rule.met ? ICON_MET : ICON_UNMET;
          item.querySelector(".navio-sr-only").textContent = " " + (rule.met ? text.ruleMet : text.ruleUnmet);
        }
      });
      window.clearTimeout(announceTimer);
      announceTimer = window.setTimeout(function () {
        rulesStatus.textContent = (text.rulesProgress || "")
          .replace("{0}", String(metCount))
          .replace("{1}", String(results.length));
      }, 700);
    }

    if (password) {
      fields.push(password);
      var rules = document.createElement("div");
      rules.className = "navio-hint navio-rules";
      rules.id = password.id + "-rules";

      var title = document.createElement("p");
      title.className = "navio-rules__title";
      title.textContent = text.rulesTitle;
      rules.appendChild(title);

      var list = document.createElement("ul");
      list.className = "navio-rules__list";
      evaluateNavioPassword("", email ? "" : undefined).forEach(function (rule) {
        var item = document.createElement("li");
        item.className = "navio-rule";
        item.dataset.met = "false";
        var icon = document.createElement("span");
        icon.className = "navio-rule__icon";
        icon.innerHTML = ICON_UNMET;
        var label = document.createElement("span");
        label.textContent = text["rule" + rule.key.charAt(0).toUpperCase() + rule.key.slice(1)];
        var state = document.createElement("span");
        state.className = "navio-sr-only";
        state.textContent = " " + text.ruleUnmet;
        item.appendChild(icon);
        item.appendChild(label);
        item.appendChild(state);
        list.appendChild(item);
        ruleItems[rule.key] = item;
      });
      rules.appendChild(list);

      rulesStatus = document.createElement("p");
      rulesStatus.className = "navio-sr-only";
      rulesStatus.setAttribute("aria-live", "polite");
      rules.appendChild(rulesStatus);

      placeBeforeErrors(password, rules);
      renderRules();

      // Keycloak's own policy script writes a length-only error on "change".
      // The checklist above replaces it, so stop that event before it reaches
      // the field. Our handlers use "input" and are unaffected.
      window.addEventListener(
        "change",
        function (event) {
          if (event.target === password) {
            event.stopPropagation();
          }
        },
        true,
      );

      password.addEventListener("input", function () {
        renderRules();
        refreshError(password);
        if (confirm) {
          renderConfirm();
          refreshError(confirm);
        }
      });
    }

    var confirmHint = null;

    function renderConfirm() {
      if (!confirmHint) {
        return;
      }
      if (confirm.value === "") {
        confirmHint.removeAttribute("data-state");
        confirmHint.textContent = text.hintConfirm;
        return;
      }
      var matches = password && confirm.value === password.value;
      confirmHint.dataset.state = matches ? "met" : "unmet";
      confirmHint.innerHTML = matches ? ICON_MET : ICON_UNMET;
      confirmHint.appendChild(document.createTextNode(matches ? text.confirmMatch : text.confirmMismatch));
    }

    if (confirm && password) {
      fields.push(confirm);
      confirmHint = addHint(confirm, text.hintConfirm);
      confirmHint.classList.add("navio-hint--status");
      confirm.addEventListener("input", function () {
        renderConfirm();
        refreshError(confirm);
      });
    }

    // Check, and focus the first problem, in the order the fields appear.
    fields.sort(function (a, b) {
      return a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1;
    });

    form.addEventListener("submit", function (event) {
      var firstInvalid = null;
      fields.forEach(function (input) {
        var message = problemWith(input);
        if (message) {
          setError(input, message);
          firstInvalid = firstInvalid || input;
        } else {
          clearError(input);
        }
      });
      if (firstInvalid) {
        event.preventDefault();
        firstInvalid.focus();
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
