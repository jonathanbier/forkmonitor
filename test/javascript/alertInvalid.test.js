import React from 'react';
import ReactDOM from 'react-dom';

import { mount, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import AlertInvalid from 'forkMonitorApp/components/alertInvalid';

const invalidBlock = {
        id: 1,
        block: {height:582689, timestamp:1558050809, hash: "00000000000000000b6f077cdfc57a62be57c757ec9f8d88d4c2ef8dfc69b141", first_seen_by: {id:3,name:"Bitcoin SV",version:100010000}},
        node: {id:21,name_with_version:"Bitcoin Unlimited 0.10.6"}
}

test('should show node name', async () => {
  const wrapper = mount(<AlertInvalid invalidBlock={ invalidBlock } />);
  expect(wrapper.text()).toContain("Bitcoin Unlimited");
});
