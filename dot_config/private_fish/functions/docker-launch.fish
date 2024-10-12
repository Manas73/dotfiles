function docker-launch --argument-names 'no-build'
  if not test -n "$no-build":
    docker build -t (basename $PWD) .
  end

  if test (basename $PWD) = ranking_service
    docker run --rm --volume (pwd):/usr/src/ranking_service -p 4003:4003 "ranking_service"
  else
    docker run $argv (basename $PWD)
  end
end
