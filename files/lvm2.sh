#!/bin/bash

# Expose various types of information about lvm2
#
# Usage: lvm-prom-collector <options>
#
# Options:
#
# -g for used and free space of logical volume groups
# -p for used and free space of physical volumes.
# -s for the percentage usage of the snapshots
# -t for the percentage usage of the thin pools
#
# * * * * *   root lvm-prom-collector -g | sponge /var/lib/prometheus/node-exporter/lvm.prom
#
# This will expose every minute information about the logical volume groups
#
# Author: Badreddin Aboubakr <badreddin.aboubakr@cloud.ionos.com>


set -eu

display_usage() {
  echo "This script must be run with super-user privileges."
  echo "Usage: lvm-prom-collector options"
  echo "Options:"
  echo "Expose various types of information about lvm2"
  echo "Use -g for used and free space of logical volume groups."
  echo "use -p for used and free space of physical volumes."
  echo "Use -s for the percentage usage of the snapshots."
  echo "Use -t for the percentage usage of the thin pools."
}

if [ "$(id -u)" != "0" ]; then
  1>&2 echo "This script must be run with super-user privileges."
  exit 1
fi

if [ $# -eq 0 ]
then
  display_usage
  exit 1
fi

thin_pools=false
snapshots=false
physical=false
groups=false

while getopts "htpsg" opt; do
  case $opt in
    p)
      physical=true
      ;;
    s)
      snapshots=true
      ;;
    g)
      groups=true
      ;;
    t)
      thin_pools=true
      ;;
    h)
      display_usage
      exit 0
      ;;
    \?)
      display_usage
      exit 1
      ;;
  esac
done

if [ "$physical" = true ] ; then
  echo "# HELP node_physical_volume_size Physical volume size in bytes"
  echo "# TYPE node_physical_volume_size gauge"

  echo "# HELP node_physical_volume_free Physical volume free space in bytes"
  echo "# TYPE node_physical_volume_free gauge"

  pvs_output=$(pvs --noheadings --units b --nosuffix --nameprefixes --unquoted --options pv_name,pv_fmt,pv_free,pv_size,pv_uuid 2>/dev/null)
  echo "$pvs_output" | while IFS= read -r line ; do
    # Skip if the line is empty
    [ -z "$line" ] && continue
    declare $line
    echo "node_physical_volume_size{name=\"$LVM2_PV_NAME\", uuid=\"$LVM2_PV_UUID\", format=\"$LVM2_PV_FMT\"} $LVM2_PV_SIZE"
    echo "node_physical_volume_free{name=\"$LVM2_PV_NAME\", uuid=\"$LVM2_PV_UUID\", format=\"$LVM2_PV_FMT\"} $LVM2_PV_FREE"
  done
fi

if [ "$snapshots" = true ] ; then
  echo "# HELP node_lvm_snapshots_allocated percentage of allocated data to a snapshot"
  echo "# TYPE node_lvm_snapshots_allocated gauge"

  lvs_output=$(lvs --noheadings --select 'lv_attr=~[^s.*]' --units b --nosuffix --unquoted --nameprefixes --options lv_uuid,vg_name,data_percent 2>/dev/null)
  echo "$lvs_output" | while IFS= read -r line ; do
    # Skip if the line is empty
    [ -z "$line" ] && continue
    declare $line
    # Convert ',' to '.'
    data_percent=$(echo "$LVM2_DATA_PERCENT" | sed 's/\,/./' )
    echo "node_lvm_snapshots_allocated{uuid=\"$LVM2_LV_UUID\", vgroup=\"$LVM2_VG_NAME\"} $data_percent"
  done
fi

if [ "$thin_pools" = true ] ; then
  echo "# HELP node_lvm_thin_pools_allocated percentage of allocated thin pool data"
  echo "# TYPE node_lvm_thin_pools_allocated gauge"

  lvs_output=$(lvs --noheadings --select 'lv_attr=~[^t.*]' --units b --nosuffix --unquoted --nameprefixes --options lv_uuid,vg_name,data_percent 2>/dev/null)
  echo "$lvs_output" | while IFS= read -r line ; do
    # Skip if the line is empty
    [ -z "$line" ] && continue
    declare $line
    # Convert ',' to '.'
    data_percent=$(echo "$LVM2_DATA_PERCENT" | sed 's/\,/./' )
    echo "node_lvm_thin_pools_allocated{uuid=\"$LVM2_LV_UUID\", vgroup=\"$LVM2_VG_NAME\"} $data_percent"
  done
fi

if [ "$groups" = true ] ; then
  echo "# HELP node_volume_group_size Volume group size in bytes"
  echo "# TYPE node_volume_group_size gauge"

  echo "# HELP node_volume_group_free volume group free space in bytes"
  echo "# TYPE node_volume_group_free gauge"

  vgs_output=$(vgs --noheadings --units b --nosuffix --unquoted --nameprefixes --options vg_name,vg_free,vg_size 2>/dev/null)
  echo "$vgs_output" | while IFS= read -r line ; do
    # Skip if the line is empty
    [ -z "$line" ] && continue
    declare $line
    echo "node_volume_group_size{name=\"$LVM2_VG_NAME\"} $LVM2_VG_SIZE"
    echo "node_volume_group_free{name=\"$LVM2_VG_NAME\"} $LVM2_VG_FREE"
  done
fi