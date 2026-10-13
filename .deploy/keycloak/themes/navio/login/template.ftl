<#import "field.ftl" as field>
<#import "footer.ftl" as loginFooter>
<#import "theme-resources.ftl" as themeResourceTags>
<#macro username>
  <#assign label>
    <#if !realm.loginWithEmailAllowed>${msg("username")}<#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}<#else>${msg("email")}</#if>
  </#assign>
  <@field.group name="username" label=label>
    <div class="${properties.kcInputGroup}">
      <div class="${properties.kcInputGroupItemClass} ${properties.kcFill}">
        <span class="${properties.kcInputClass} ${properties.kcFormReadOnlyClass}">
          <input id="kc-attempted-username" value="${auth.attemptedUsername}" readonly>
        </span>
      </div>
      <div class="${properties.kcInputGroupItemClass}">
        <button id="reset-login" class="${properties.kcFormPasswordVisibilityButtonClass} kc-login-tooltip" type="button"
              aria-label="${msg('restartLoginTooltip')}" onclick="location.href='${url.loginRestartFlowUrl}'">
            <i class="fa-sync-alt fas" aria-hidden="true"></i>
            <span class="kc-tooltip-text">${msg("restartLoginTooltip")}</span>
        </button>
      </div>
    </div>
  </@field.group>
</#macro>

<#macro registrationLayout bodyClass="" displayInfo=false displayMessage=true displayRequiredFields=false>
<!DOCTYPE html>
<html class="${properties.kcHtmlClass!}" lang="${lang}"<#if realm.internationalizationEnabled> dir="${(locale.rtl)?then('rtl','ltr')}"</#if>>

<head>
    <meta charset="utf-8">
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <meta name="color-scheme" content="light${darkMode?then(' dark', '')}">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <#if properties.meta?has_content>
        <#list properties.meta?split(' ') as meta>
            <meta name="${meta?split('==')[0]}" content="${meta?split('==')[1]}"/>
        </#list>
    </#if>
    <title>${title!}</title>
    <#if themeResources?? && themeResources.favicons?has_content>
        <@themeResourceTags.renderFavicons themeResources.favicons url.resourcesPath />
    <#else>
        <link rel="icon" href="${url.resourcesPath}/img/favicon.ico" />
    </#if>
    <#if themeResources?? && themeResources.stylesCommon?has_content>
        <@themeResourceTags.renderStyles themeResources.stylesCommon url.resourcesCommonPath />
    <#elseif properties.stylesCommon?has_content>
        <#list properties.stylesCommon?split(' ') as style>
            <link href="${url.resourcesCommonPath}/${style}" rel="stylesheet" />
        </#list>
    </#if>
    <#if themeResources?? && themeResources.styles?has_content>
        <@themeResourceTags.renderStyles themeResources.styles url.resourcesPath />
    <#elseif properties.styles?has_content>
        <#list properties.styles?split(' ') as style>
            <link href="${url.resourcesPath}/${style}" rel="stylesheet" />
        </#list>
    </#if>
    <script type="importmap">
        {
            "imports": {
                "rfc4648": "${url.resourcesCommonPath}/vendor/rfc4648/rfc4648.js"
            }
        }
    </script>
    <#if darkMode>
      <script type="module" async blocking="render">
          <#outputformat "JavaScript">
          const DARK_MODE_CLASS = ${properties.kcDarkModeClass?c};
          const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");

          updateDarkMode(mediaQuery.matches);
          mediaQuery.addEventListener("change", (event) => updateDarkMode(event.matches));

          function updateDarkMode(isEnabled) {
            const { classList } = document.documentElement;

            if (isEnabled) {
              classList.add(DARK_MODE_CLASS);
            } else {
              classList.remove(DARK_MODE_CLASS);
            }
          }
          </#outputformat>
      </script>
    </#if>
    <#if themeResources?? && themeResources.scripts?has_content>
        <@themeResourceTags.renderScripts themeResources.scripts url.resourcesPath "text/javascript" />
    <#elseif properties.scripts?has_content>
        <#list properties.scripts?split(' ') as script>
            <script src="${url.resourcesPath}/${script}" type="text/javascript"></script>
        </#list>
    </#if>
    <#if scripts??>
        <#list scripts as script>
            <script src="${script}" type="text/javascript"></script>
        </#list>
    </#if>
    <script type="module" src="${url.resourcesPath}/js/passwordVisibility.js"></script>
    <script type="module">
        <#outputformat "JavaScript">
        import { startSessionPolling } from ${(url.resourcesPath + "/js/authChecker.js")?c};

        startSessionPolling(
            ${url.ssoLoginInOtherTabsUrl?c}
        );
        </#outputformat>
    </script>
    <script type="module">
        document.addEventListener("click", (event) => {
            const link = event.target.closest("a[data-once-link]");

            if (!link) {
                return;
            }

            if (link.getAttribute("aria-disabled") === "true") {
                event.preventDefault();
                return;
            }

            const { disabledClass } = link.dataset;

            if (disabledClass) {
                link.classList.add(...disabledClass.trim().split(/\s+/));
            }

            link.setAttribute("role", "link");
            link.setAttribute("aria-disabled", "true");
        });
    </script>
    <#if authenticationSession??>
        <script type="module">
             <#outputformat "JavaScript">
            import { checkAuthSession } from ${(url.resourcesPath + "/js/authChecker.js")?c};

            checkAuthSession(
                ${authenticationSession.authSessionIdHash?c}
            );
            </#outputformat>
        </script>
    </#if>
    <script>
      // Workaround for https://bugzilla.mozilla.org/show_bug.cgi?id=1404468
      const isFirefox = true;
    </script>
</head>

<body id="keycloak-bg" class="${properties.kcBodyClass!}" data-page-id="login-${pageId}">
<#--
  Navio: everything below the <body> tag up to <main> replaces keycloak.v2's
  centred card with a split page. The left panel is decorative art only; the
  form markup inside <main> is unchanged so Keycloak's validation, password
  toggle and accessibility behaviour keep coming from the parent theme.
-->
<div class="${properties.kcLogin!} navio-auth">
  <#-- Decorative only: flowing lines with light pulses over a slow aurora glow. -->
  <div class="navio-art" aria-hidden="true">
    <div class="navio-art__glow navio-art__glow--blue"></div>
    <div class="navio-art__glow navio-art__glow--cyan"></div>
    <div class="navio-art__glow navio-art__glow--green"></div>
    <svg class="navio-art__ribbon" viewBox="0 0 800 1000" preserveAspectRatio="xMidYMid slice" focusable="false">
      <defs>
        <linearGradient id="navio-art-stroke" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" class="navio-art__stop--blue"/>
          <stop offset="0.55" class="navio-art__stop--cyan"/>
          <stop offset="1" class="navio-art__stop--green"/>
        </linearGradient>
      </defs>
      <g class="navio-art__drift">
        <g class="navio-art__lines" stroke="url(#navio-art-stroke)">
          <path d="M-100 560C200 120 560 1060 920 140"/>
          <path d="M-100 573C212 146 541 1040 920 150"/>
          <path d="M-100 586C224 172 522 1021 920 161"/>
          <path d="M-100 599C236 199 503 1001 920 171"/>
          <path d="M-100 612C247 225 485 980 920 181"/>
          <path d="M-100 626C259 251 467 960 920 192"/>
          <path d="M-100 639C269 277 450 939 920 202"/>
          <path d="M-100 652C280 303 435 917 920 212"/>
          <path d="M-100 665C290 330 420 895 920 223"/>
          <path d="M-100 678C299 356 407 872 920 233"/>
          <path d="M-100 691C308 382 395 848 920 243"/>
          <path d="M-100 704C316 408 384 823 920 254"/>
          <path d="M-100 717C324 434 375 798 920 264"/>
          <path d="M-100 730C331 461 368 771 920 274"/>
          <path d="M-100 743C337 487 362 744 920 285"/>
          <path d="M-100 757C343 513 358 716 920 295"/>
          <path d="M-100 770C347 539 356 687 920 306"/>
          <path d="M-100 783C352 566 355 656 920 316"/>
          <path d="M-100 796C355 592 355 625 920 326"/>
          <path d="M-100 809C358 618 358 593 920 337"/>
          <path d="M-100 822C360 644 361 561 920 347"/>
          <path d="M-100 835C362 670 366 527 920 357"/>
          <path d="M-100 848C363 697 373 493 920 368"/>
          <path d="M-100 861C363 723 380 458 920 378"/>
          <path d="M-100 874C363 749 389 423 920 388"/>
          <path d="M-100 888C363 775 398 387 920 399"/>
          <path d="M-100 901C363 801 408 350 920 409"/>
          <path d="M-100 914C362 828 418 314 920 419"/>
          <path d="M-100 927C361 854 429 277 920 430"/>
          <path d="M-100 940C360 880 440 240 920 440"/>
        </g>
        <g class="navio-art__pulses" stroke="url(#navio-art-stroke)">
          <path d="M-100 560C200 120 560 1060 920 140" pathLength="1" style="--navio-pulse-duration: 6.0s; --navio-pulse-delay: -0.0s; --navio-pulse-rest: -0.20"/>
          <path d="M-100 586C224 172 522 1021 920 161" pathLength="1" style="--navio-pulse-duration: 10.0s; --navio-pulse-delay: -2.3s; --navio-pulse-rest: -0.57"/>
          <path d="M-100 612C247 225 485 980 920 181" pathLength="1" style="--navio-pulse-duration: 9.2s; --navio-pulse-delay: -4.6s; --navio-pulse-rest: -0.34"/>
          <path d="M-100 639C269 277 450 939 920 202" pathLength="1" style="--navio-pulse-duration: 8.4s; --navio-pulse-delay: -6.9s; --navio-pulse-rest: -0.71"/>
          <path d="M-100 665C290 330 420 895 920 223" pathLength="1" style="--navio-pulse-duration: 7.6s; --navio-pulse-delay: -1.6s; --navio-pulse-rest: -0.48"/>
          <path d="M-100 691C308 382 395 848 920 243" pathLength="1" style="--navio-pulse-duration: 6.8s; --navio-pulse-delay: -4.7s; --navio-pulse-rest: -0.25"/>
          <path d="M-100 717C324 434 375 798 920 264" pathLength="1" style="--navio-pulse-duration: 6.0s; --navio-pulse-delay: -1.8s; --navio-pulse-rest: -0.62"/>
          <path d="M-100 743C337 487 362 744 920 285" pathLength="1" style="--navio-pulse-duration: 10.0s; --navio-pulse-delay: -6.1s; --navio-pulse-rest: -0.39"/>
          <path d="M-100 770C347 539 356 687 920 306" pathLength="1" style="--navio-pulse-duration: 9.2s; --navio-pulse-delay: -0.0s; --navio-pulse-rest: -0.76"/>
          <path d="M-100 796C355 592 355 625 920 326" pathLength="1" style="--navio-pulse-duration: 8.4s; --navio-pulse-delay: -3.9s; --navio-pulse-rest: -0.53"/>
          <path d="M-100 822C360 644 361 561 920 347" pathLength="1" style="--navio-pulse-duration: 7.6s; --navio-pulse-delay: -0.2s; --navio-pulse-rest: -0.30"/>
          <path d="M-100 848C363 697 373 493 920 368" pathLength="1" style="--navio-pulse-duration: 6.8s; --navio-pulse-delay: -4.9s; --navio-pulse-rest: -0.67"/>
          <path d="M-100 874C363 749 389 423 920 388" pathLength="1" style="--navio-pulse-duration: 6.0s; --navio-pulse-delay: -3.6s; --navio-pulse-rest: -0.44"/>
          <path d="M-100 901C363 801 408 350 920 409" pathLength="1" style="--navio-pulse-duration: 10.0s; --navio-pulse-delay: -9.9s; --navio-pulse-rest: -0.21"/>
          <path d="M-100 927C361 854 429 277 920 430" pathLength="1" style="--navio-pulse-duration: 9.2s; --navio-pulse-delay: -4.6s; --navio-pulse-rest: -0.58"/>
        </g>
      </g>
    </svg>
  </div>

  <div class="${properties.kcLoginContainer!} navio-auth__panel">
    <main class="${properties.kcLoginMain!}">
      <div class="${properties.kcLoginMainHeader!}">
        <div class="navio-brand">
          <svg class="navio-logo" viewBox="0 0 39 48" aria-hidden="true" focusable="false">
            <g fill="currentColor">
              <path d="m30 4.5c4.9706 0 9 4.02944 9 9 0 4.9706-4.0294 9-9 9h-9v-9c0-4.97056 4.0294-9 9-9z" opacity=".5"/>
              <path d="m0 13.5c0-4.97056 4.02944-9 9-9 4.9706 0 9 4.02944 9 9v9h-9c-4.97056 0-9-4.0294-9-9z"/>
              <path d="m9 43.5c-4.97056 0-9.00000006-4.0294-9-9s4.02944-9 9-9h9v9c0 4.9706-4.0294 9-9 9z"/>
              <path d="m39 34.5c0 4.9706-4.0294 9-9 9s-9-4.0294-9-9v-9h9c4.9706 0 9 4.0294 9 9z"/>
            </g>
          </svg>
          <span class="navio-brand__name">Navio</span>
        </div>
        <h1 class="${properties.kcLoginMainTitle!}" id="kc-page-title"><#nested "header"></h1>
        <#if realm.internationalizationEnabled  && locale.supported?size gt 1>
        <div class="${properties.kcLoginMainHeaderUtilities!}">
          <div class="${properties.kcInputClass!}">
            <select
              aria-label="${msg("languages")}"
              id="login-select-toggle"
              onchange="if (this.value) window.location.href=this.value"
            >
              <#list locale.supported?sort_by("label") as l>
                <option
                  value="${l.url}"
                  ${(l.languageTag == locale.currentLanguageTag)?then('selected','')}
                >
                  ${l.label}
                </option>
              </#list>
            </select>
            <span class="${properties.kcFormControlUtilClass}">
              <span class="${properties.kcFormControlToggleIcon!}">
                <svg
                  class="pf-v5-svg"
                  viewBox="0 0 320 512"
                  fill="currentColor"
                  aria-hidden="true"
                  role="img"
                  width="1em"
                  height="1em"
                >
                  <path
                    d="M31.3 192h257.3c17.8 0 26.7 21.5 14.1 34.1L174.1 354.8c-7.8 7.8-20.5 7.8-28.3 0L17.2 226.1C4.6 213.5 13.5 192 31.3 192z"
                  >
                  </path>
                </svg>
              </span>
            </span>
          </div>
        </div>
        </#if>
      </div>
      <div class="${properties.kcLoginMainBody!}">
        <#if !(auth?has_content && auth.showUsername() && !auth.showResetCredentials())>
            <#if displayRequiredFields>
                <div class="${properties.kcContentWrapperClass!}">
                    <div class="${properties.kcLabelWrapperClass!} subtitle">
                        <span class="${properties.kcInputHelperTextItemTextClass!}">
                          <span class="${properties.kcInputRequiredClass!}">*</span> ${msg("requiredFields")}
                        </span>
                    </div>
                </div>
            </#if>
        <#else>
            <#if displayRequiredFields>
                <div class="${properties.kcContentWrapperClass!}">
                    <div class="${properties.kcLabelWrapperClass!} subtitle">
                        <span class="${properties.kcInputHelperTextItemTextClass!}">
                          <span class="${properties.kcInputRequiredClass!}">*</span> ${msg("requiredFields")}
                        </span>
                    </div>
                    <div class="${properties.kcFormClass} ${properties.kcContentWrapperClass}">
                        <#nested "show-username">
                        <@username />
                    </div>
                </div>
            <#else>
                <div class="${properties.kcFormClass} ${properties.kcContentWrapperClass}">
                  <#nested "show-username">
                  <@username />
                </div>
            </#if>
        </#if>

        <#-- App-initiated actions should not see warning messages about the need to complete the action -->
        <#-- during login.                                                                               -->
        <#if displayMessage && message?has_content && (message.type != 'warning' || !isAppInitiatedAction??)>
            <div class="${properties.kcAlertClass!} pf-m-${(message.type = 'error')?then('danger', message.type)}">
                <div class="${properties.kcAlertIconClass!}">
                    <#if message.type = 'success'><span class="${properties.kcFeedbackSuccessIcon!}"></span></#if>
                    <#if message.type = 'warning'><span class="${properties.kcFeedbackWarningIcon!}"></span></#if>
                    <#if message.type = 'error'><span class="${properties.kcFeedbackErrorIcon!}"></span></#if>
                    <#if message.type = 'info'><span class="${properties.kcFeedbackInfoIcon!}"></span></#if>
                </div>
                <span class="${properties.kcAlertTitleClass!} kc-feedback-text">${message.summary}</span>
            </div>
        </#if>

        <#nested "form">

        <#if auth?has_content && auth.showTryAnotherWayLink()>
          <form id="kc-select-try-another-way-form" action="${url.loginAction}" method="post" novalidate="novalidate">
              <input type="hidden" name="tryAnotherWay" value="on"/>
              <a id="try-another-way" href="javascript:document.forms['kc-select-try-another-way-form'].requestSubmit()"
                  class="${properties.kcButtonSecondaryClass} ${properties.kcButtonBlockClass} ${properties.kcMarginTopClass}">
                    ${msg("doTryAnotherWay")}
              </a>
          </form>
        </#if>

        <#if switchOrganizationEnabled?? && switchOrganizationEnabled>
          <form id="kc-switch-organization-form" action="${url.loginAction}" method="post" novalidate="novalidate">
              <input type="hidden" name="switchOrganization" value="true"/>
              <a id="switch-organization" href="javascript:document.forms['kc-switch-organization-form'].requestSubmit()"
                  class="${properties.kcButtonSecondaryClass} ${properties.kcButtonBlockClass} ${properties.kcMarginTopClass}">
                    ${msg("doSwitchOrganization")}
              </a>
          </form>
        </#if>

          <div class="${properties.kcLoginMainFooter!}">
              <#nested "socialProviders">

              <#if displayInfo>
                  <div id="kc-info" class="${properties.kcLoginMainFooterBand!} ${properties.kcFormClass}">
                      <div id="kc-info-wrapper" class="${properties.kcLoginMainFooterBandItem!}">
                          <#nested "info">
                      </div>
                  </div>
              </#if>
          </div>
      </div>

        <div class="${properties.kcLoginMainFooter!}">
            <@loginFooter.content/>
        </div>
    </main>
  </div>
</div>
</body>
</html>
</#macro>
