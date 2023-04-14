import React from 'react';
import {
  List,
  Edit,
  Create,
  Datagrid,
  BooleanField,
  TextField,
  DateField,
  NumberField,
  SimpleForm,
  NumberInput,
  TextInput,
  SelectInput,
  BooleanInput,
  DateInput,
} from 'react-admin';

const client_choices = [
    { id: "core", name: "Bitcoin Core"},
    { id: "bcoin", name: "bcoin"},
    { id: "knots", name: "Knots"},
    { id: "btcd", name: "Btcd"},
    { id: "libbitcoin", name: "libbitcoin"},
    { id: "omni", name: "omni"},
    { id: "blockcore", name: "Blockcore"},
    { id: "bu", name: "Bitcoin Unlimited"},
];

export const NodeList = props => (
    <List {...props}
        sort={{ field: "id"}}
        bulkActionButtons={false}
        >
        <Datagrid rowClick="edit">
            <NumberField source="id" />
            <TextField source="name_with_version" />
            <DateField source="unreachable_since" />
            <BooleanField source="enabled" />
        </Datagrid>
    </List>
);

export const NodeEdit = props => (
    <Edit {...props}>
        <SimpleForm>
            <TextField source="name_with_version" readOnly />
            <TextInput source="name" />
            <TextInput source="version_extra" />
            <TextInput source="link" />
            <TextInput source="link_text" />
            <TextInput source="rpchost" />
            <TextInput source="mirror_rpchost" />
            <NumberInput source="rpcport" />
            <NumberInput source="mirror_rpcport" />
            <TextInput source="rpcuser" />
            <TextInput source="rpcpassword" />
            <BooleanInput source="pruned" />
            <BooleanInput source="txindex" />
            <TextInput source="os" />
            <TextInput source="cpu" />
            <NumberInput source="ram" />
            <TextInput source="storage" />
            <BooleanInput source="cve_2018_17144" />
            <BooleanInput source="checkpoints" />
            <BooleanInput source="getblocktemplate" />
            <DateInput source="released" />
            <BooleanInput source="enabled" />
        </SimpleForm>
    </Edit>
);

export const NodeCreate = props => (
    <Create {...props}>
        <SimpleForm>
            <TextInput source="name" defaultValue="Bitcoin Core" />
            <SelectInput source="client_type" defaultValue="core" choices={ client_choices } />
            <TextInput source="version_extra" />
            <TextInput source="link" />
            <TextInput source="link_text" />
            <TextInput source="rpchost" />
            <TextInput source="mirror_rpchost" />
            <NumberInput source="rpcport" />
            <NumberInput source="mirror_rpcport" />
            <TextInput source="rpcuser" />
            <TextInput source="rpcpassword" />
            <BooleanInput source="pruned" />
            <BooleanInput source="txindex" />
            <TextInput source="os" />
            <TextInput source="cpu" />
            <NumberInput source="ram" />
            <TextInput source="storage" />
            <BooleanInput source="cve_2018_17144" />
            <BooleanInput source="checkpoints" />
            <BooleanInput source="getblocktemplate" />
            <DateInput source="released" />
        </SimpleForm>
    </Create>
);
