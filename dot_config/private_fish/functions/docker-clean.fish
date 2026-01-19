function docker-clean --description "Remove all Docker containers, images, and volumes"
    argparse h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: docker-clean [OPTIONS]"
        echo ""
        echo "Remove all Docker containers, images, and volumes."
        echo ""
        echo "Options:"
        echo "  --help, -h      Show this help message"
        echo ""
        echo "Warning: This will forcefully remove ALL containers, images, and volumes!"
        return 0
    end

    docker rm -vf (docker ps -a -q)
    docker rmi -f (docker images -a -q)
    docker volume rm (docker volume ls -q)
end
