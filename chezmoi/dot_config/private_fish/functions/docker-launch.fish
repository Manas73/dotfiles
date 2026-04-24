function docker-launch --description "Build and launch a Docker container for the current project"
    argparse h/help n/no-build -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: docker-launch [OPTIONS] [DOCKER_ARGS...]"
        echo ""
        echo "Build and launch a Docker container for the current project."
        echo ""
        echo "Options:"
        echo "  --help, -h         Show this help message"
        echo "  --no-build, -n     Skip building the image"
        echo ""
        echo "Arguments:"
        echo "  DOCKER_ARGS        Additional arguments to pass to 'docker run'"
        return 0
    end

    if not set -q _flag_no_build
        docker build -t (basename $PWD) .
    end

    if test (basename $PWD) = ranking_service
        docker run --rm --volume (pwd):/usr/src/ranking_service -p 4003:4003 "ranking_service"
    else
        docker run $argv (basename $PWD)
    end
end
