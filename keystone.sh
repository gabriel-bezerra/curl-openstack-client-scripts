KEYSTONE_HOST=${KEYSTONE_HOST:-localhost}

# Domain
function create_domain() {
  local TOKEN=$1
  local DOMAIN_NAME=$2

  curl -H "X-Auth-Token: $TOKEN" -H "Content-type: application/json" \
       -d '{"domain": {"description": "--optional--", "enabled": true, "name": "'"$DOMAIN_NAME"'"}}' \
       http://$KEYSTONE_HOST:5000/v3/domains \
    | ./jq '.domain.id' -r
}

function delete_domain() {
  local TOKEN=$1
  local DOMAIN_ID=$2

  # Disable domain
  local OLD_DATA=$(curl -H "X-Auth-Token: $TOKEN" http://$KEYSTONE_HOST:5000/v3/domains/$DOMAIN_ID)
  local NEW_DATA=$(echo $OLD_DATA | ./jq '.domain.enabled|=false')

  curl -H "X-Auth-Token: $TOKEN" -H "Content-type: application/json" \
       -X PATCH -d "$NEW_DATA" \
       http://$KEYSTONE_HOST:5000/v3/domains/$DOMAIN_ID > /dev/null

  # Delete domain
  curl -H "X-Auth-Token: $TOKEN" -H "Content-type: application/json" \
       -X DELETE \
       http://$KEYSTONE_HOST:5000/v3/domains/$DOMAIN_ID
}

function get_domains() {
  local TOKEN=$1

  curl -H "X-Auth-Token: $TOKEN" http://$KEYSTONE_HOST:5000/v3/domains
}

function domainid_from_name() {
  local TOKEN=$1
  local DOMAIN_NAME=$2

  get_domains $TOKEN | ./jq -r ".domains[] | select(.name == \"$DOMAIN_NAME\") | .id"
}

# Project
function create_project() {
  local TOKEN=$1
  local DOMAIN_ID=$2
  local PROJECT_NAME=$3

  curl -H "X-Auth-Token: $TOKEN" -H "Content-type: application/json" \
       -d '{"project": {"description": "--optional--", "domain_id": "'"$DOMAIN_ID"'", "enabled": true, "name": "'"$PROJECT_NAME"'"}}' \
       http://$KEYSTONE_HOST:5000/v3/projects \
    | ./jq '.project.id' -r
}

# Role
function add_domain_role() {
  local TOKEN=$1
  local USER_ID=$2
  local DOMAIN_ID=$3
  local ROLE_ID=$4

  curl -X PUT -H "X-Auth-Token: $TOKEN" "http://$KEYSTONE_HOST:5000/v3/domains/$DOMAIN_ID/users/$USER_ID/roles/$ROLE_ID"
}

function add_group_role() {
  local TOKEN=$1
  local PROJECT_ID=$2
  local GROUP_ID=$3
  local ROLE_ID=$4

  curl -X PUT -H "X-Auth-Token: $TOKEN" "http://$KEYSTONE_HOST:5000/v3/projects/$PROJECT_ID/groups/$GROUP_ID/roles/$ROLE_ID"
}

function roleid_from_name() {
  local TOKEN=$1
  local ROLE_NAME=$2

  curl -X GET -H "X-Auth-Token: $TOKEN" "http://$KEYSTONE_HOST:5000/v3/roles" | ./jq -r ".roles[] | select(.name == \"$ROLE_NAME\") | .id"
}

# User
function create_user() {
  local TOKEN=$1
  local DOMAIN_ID=$2
  local NAME=$3
  local PASSWORD=$4

  #FIXME change default-project-id
  local DATA=$(cat <<EOF
{ 
    "user": { 
        "default_project_id": "d0f445c3379b48f38a2ab0f17314bbf9", 
        "description": "Description", 
        "domain_id": "$DOMAIN_ID",
        "email": "email@email.com", 
        "enabled": true, 
        "name": "$NAME", 
        "password": "$PASSWORD"
    } 
}
EOF
)

  curl -H "X-Auth-Token: $TOKEN" -H "Content-type: application/json" -d "$DATA" \
       http://$KEYSTONE_HOST:5000/v3/users \
    | ./jq -r .user.id
}

# Group
function create_group() {
  local TOKEN=$1
  local DOMAIN_ID=$2
  local GROUP_NAME=$3

  curl -H "X-Auth-Token: $TOKEN" -H "Content-type: application/json" \
       -d '{"group": {"description": "--optional--", "domain_id": "'"$DOMAIN_ID"'", "name": "'"$GROUP_NAME"'"}}' \
       http://$KEYSTONE_HOST:5000/v3/groups \
    | ./jq '.group.id' -r
}

function delete_group() {
  local TOKEN=$1
  local GROUP_ID=$2

  curl -H "X-Auth-Token: $TOKEN" -X DELETE \
       http://$KEYSTONE_HOST:5000/v3/groups/$GROUP_ID
}

# Federation - Mapping
function create_mapping() {
  local TOKEN=$1
  local MAPPING_ID=$2
  local RULES=$3

  local DATA=$(cat <<EOF
{
    "mapping": {
        "rules": [
            $RULES
        ]
    }
}
EOF
)

  curl -H "X-Auth-Token: $TOKEN" -H "Content-type: application/json" \
       -d "$DATA" \
       -X PUT \
       http://$KEYSTONE_HOST:5000/v3/OS-FEDERATION/mappings/$MAPPING_ID \
    | ./jq '.mapping.id' -r
}

function create_mapping_with_single_rule() {
  local TOKEN=$1
  local MAPPING_ID=$2
  local GROUP_ID=$3
  local REMOTE_RULES=$4

  local RULE=$(cat <<EOF
    {
        "local": [
            {
                "user": {
                    "name": "federated-user"
                }
            },
            {
                "group": {
                    "id": "$GROUP_ID"
                }
            }
        ],
        "remote": [
            $REMOTE_RULES
        ]
    }
EOF
)

  create_mapping $TOKEN $MAPPING_ID $RULE
}

function delete_mapping() {
  local TOKEN=$1
  local MAPPING_ID=$2

  curl -H "X-Auth-Token: $TOKEN" -X DELETE \
       http://$KEYSTONE_HOST:5000/v3/OS-FEDERATION/mappings/$MAPPING_ID
}

function get_mappings() {
  local TOKEN=$1

  curl -H "X-Auth-Token: $TOKEN" http://$KEYSTONE_HOST:5000/v3/OS-FEDERATION/mappings
}

function mappingid_from_name() {
  local TOKEN=$1
  local MAPPING_NAME=$2

  get_mappings $TOKEN | ./jq -r ".mappings[] | select(.id == \"$MAPPING_NAME\") | .id"
}

# Federation - Identity Provider
function register_identity_provider() {
  local TOKEN=$1
  local IDP_ID=$2

  curl -H "X-Auth-Token: $TOKEN" -H "Content-type: application/json" \
       -d '{"identity_provider": {"description": "--optional--", "enabled": true}}' \
       -X PUT \
       http://$KEYSTONE_HOST:5000/v3/OS-FEDERATION/identity_providers/$IDP_ID \
    | ./jq '.identity_provider.id' -r
}

function delete_identity_provider() {
  local TOKEN=$1
  local IDP_ID=$2

  curl -H "X-Auth-Token: $TOKEN" -X DELETE \
       http://$KEYSTONE_HOST:5000/v3/OS-FEDERATION/identity_providers/$IDP_ID
}

function get_identity_providers() {
  local TOKEN=$1

  curl -H "X-Auth-Token: $TOKEN" http://$KEYSTONE_HOST:5000/v3/OS-FEDERATION/identity_providers
}

function identity_provider_id_from_name() {
  local TOKEN=$1
  local IDP_NAME=$2

  get_identity_providers $TOKEN | ./jq -r ".identity_providers[] | select(.id == \"$IDP_NAME\") | .id"
}

# Federation - Protocol
function register_protocol() {
  local TOKEN=$1
  local IDP_ID=$2
  local MAPPING_ID=$3
  local PROTOCOL_ID=$4

  curl -H "X-Auth-Token: $TOKEN" -H "Content-type: application/json" \
       -d '{"protocol": {"mapping_id": "'"$MAPPING_ID"'"}}' \
       -X PUT \
       http://$KEYSTONE_HOST:5000/v3/OS-FEDERATION/identity_providers/$IDP_ID/protocols/$PROTOCOL_ID \
    | ./jq '.protocol.id' -r
}

function get_protocols() {
  local TOKEN=$1
  local IDP_ID=$2

  curl -H "X-Auth-Token: $TOKEN" http://$KEYSTONE_HOST:5000/v3/OS-FEDERATION/identity_providers/$IDP_ID/protocols
}

# Federation - Projects and Domains
function federation_projects() {
  local FEDERATED_TOKEN=$1

  curl -H "X-Auth-Token: $FEDERATED_TOKEN" \
       http://$KEYSTONE_HOST:5000/v3/OS-FEDERATION/projects
}

function federation_domains() {
  local FEDERATED_TOKEN=$1

  curl -H "X-Auth-Token: $FEDERATED_TOKEN" \
       http://$KEYSTONE_HOST:5000/v3/OS-FEDERATION/domains
}

# Federation - Token
function get_project_scoped_token_from_federated_token() {
  local FEDERATED_TOKEN=$1
  local SCOPE_DOMAIN_NAME=$2
  local SCOPE_PROJECT_NAME=$3

  local DATA=$(cat <<EOF
{
    "auth": {
        "identity": {
            "methods": [
                "saml2"
            ],
            "saml2": {
                "id": "$FEDERATED_TOKEN"
            }
        },
        "scope": {
           "project": {
                "domain": {
                    "name": "$SCOPE_DOMAIN_NAME"
                },
                "name": "$SCOPE_PROJECT_NAME"
            }
         }
      }
}
EOF
)

  curl -si -d "$DATA" -H "Content-type: application/json" http://$KEYSTONE_HOST:5000/v3/auth/tokens | awk '/X-Subject-Token/ {print $2}' | sed 's/\r$//'
}

# Token
function get_project_scoped_token() {
  local USER_DOMAIN_NAME=$1
  local USER_NAME=$2
  local USER_PASSWORD=$3
  local SCOPE_DOMAIN_NAME=$4
  local SCOPE_PROJECT_NAME=$5

  local DATA=$(cat <<EOF
{
    "auth": {
        "identity": {
            "methods": [
                "password"
            ],
            "password": {
                "user": {
                    "domain": {
                        "name": "$USER_DOMAIN_NAME"
                    },
                    "name": "$USER_NAME",
                    "password": "$USER_PASSWORD"
                }
            }
        },
        "scope": {
           "project": {
                "domain": {
                    "name": "$SCOPE_DOMAIN_NAME"
                },
                "name": "$SCOPE_PROJECT_NAME"
            }
         }
      }
}
EOF
)

  curl -si -d "$DATA" -H "Content-type: application/json" http://$KEYSTONE_HOST:5000/v3/auth/tokens | awk '/X-Subject-Token/ {print $2}' | sed 's/\r$//'
}

function get_domain_scoped_token() {
  local USER_NAME=$1
  local USER_PASSWORD=$2
  local USER_DOMAIN_NAME=$3
  local SCOPE_DOMAIN_NAME=$4

  local DATA=$(cat << EOF
{
    "auth": {
        "identity": {
            "methods": [
                "password"
                ],
                "password": {
                    "user": {
                        "domain": {
                            "name": "$USER_DOMAIN_NAME"
                        },
                        "name": "$USER_NAME",
                        "password": "$USER_PASSWORD"
                    }
                }
        },
        "scope": {
            "domain": {
                "name": "$SCOPE_DOMAIN_NAME"
            }
         }
      }
}
EOF
)

  curl -si -d "$DATA" -H "Content-type: application/json" http://$KEYSTONE_HOST:5000/v3/auth/tokens | awk '/X-Subject-Token/ {print $2}' | sed 's/\r$//'
}

function validate_token() {
  local AUTH_TOKEN=$1
  local SUBJECT_TOKEN=$2

  curl -H "X-Auth-Token: $AUTH_TOKEN" -H "X-Subject-Token: $SUBJECT_TOKEN" http://$KEYSTONE_HOST:5000/v3/auth/tokens
}
