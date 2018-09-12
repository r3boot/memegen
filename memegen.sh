#!/bin/sh

#set -x

WRKDIR="$(mktemp -d)"
trap "rm -rf ${WRKDIR}" INT TERM EXIT

IMGDIR="$(readlink -f $(dirname ${0})/imgs)"
JQ="jq -r"

NAME="${1}"
shift

if [[ ! -d "${IMGDIR}/${NAME}" ]]; then
    echo "[E] Meme ${NAME} not found, exiting ..."
    exit 1
fi

IMG="${IMGDIR}/${NAME}/source.jpg"
if [[ ! -f "${IMG}" ]]; then
    echo "[E] ${IMG} not found, exiting ..."
    exit 1
fi

META="${IMGDIR}/${NAME}/meta.json"
if [[ ! -f "${META}" ]]; then
    echo "[E] ${META} not found, exiting ..."
    exit 1
fi

FILL_COLOR="$(cat ${META} | ${JQ} .fill)"
FONT_SIZE="$(cat ${META} | ${JQ} .font_size)"
NUM_ANNOTATIONS=$(cat ${META} | ${JQ} .num_annotations)

if [[ ${#} -ne ${NUM_ANNOTATIONS} ]]; then
    echo "[E] ${NAME} needs ${NUM_ANNOTATIONS} annotations, exiting ..."
    exit 1
fi

ANNOTATIONS=""
for IDX in $(seq ${NUM_ANNOTATIONS}); do
    VALUE="${1}"
    shift
    COORDINATES="$(cat ${META} | ${JQ} ".annotations[$(expr ${IDX} - 1)]")"
    ANNOTATIONS="${ANNOTATIONS} -annotate ${COORDINATES} \"${VALUE}\""
done

echo '[+] Generating image'
DESTFILE="${WRKDIR}/upload.jpg"
COMMAND="convert -pointsize "${FONT_SIZE}" -fill "${FILL_COLOR}" "${ANNOTATIONS}" ${IMG} ${DESTFILE}"
eval ${COMMAND}

echo '[+] Uploading image to imgur'
HASH=$(curl -s -XPOST \
    -H "Referer: https://imgur.com/upload" \
    -F "Filedata=@\"${DESTFILE}\";filename=${DESTFILE};type=image/png" \
    "https://imgur.com/upload" \
    | jq -r .data.hash)

if [[ -z "${HASH}" ]]; then
    echo '[E] Failed to upload image to imgur'
    exit 1
fi
echo "[+] Uploaded to https://imgur.com/${HASH}"

echo '[+] Opening image in browser'
xdg-open "https://imgur.com/${HASH}"
