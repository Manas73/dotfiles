# Loaded by ~/.gitconfig via includeIf for clones under:
#   ~/Repositories/github.com/manas-turing/
#   ~/Repositories/github.com/TuringEnterprises/
#   ~/Repositories/github.com/turing-genai-apps/
#   ~/Repositories/github.com/TuringGpt/
#
# Overrides the default Manas73 rewrite (set in ~/.gitconfig) with the
# manas-turing rewrite so the credential helper returns the Turing token
# for Turing clones.
#
# Later url.insteadOf entries win, so simply redeclaring the rewrite
# here is enough; no need to unset the personal one.

[url "https://manas-turing@github.com/"]
	insteadOf = https://github.com/

[user]
	email = manas.s@turing.com
