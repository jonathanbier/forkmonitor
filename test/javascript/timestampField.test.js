import React from 'react';
import ReactDOM from 'react-dom';

import { mount, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import TimestampField from 'forkMonitorApp/components/timestampField';

const block = {
  timestamp: 1567444304
}

let wrapper;

describe('TimestampField', () => {

  test('should render date', () => {
    wrapper = mount(<TimestampField
      record={ {timestamp: block.timestamp} }
      source="timestamp"
    />)
    expect(wrapper.text()).toEqual("2019-09-02 17:11");
  });
  
  test('should render date from nested value', () => {
    wrapper = mount(<TimestampField
      record={ {block: block} }
      source="block.timestamp"
    />)
    expect(wrapper.text()).toEqual("2019-09-02 17:11");
  });
  
  test('should render empty date', () => {
    wrapper = mount(<TimestampField
      record={ {timestamp: null} }
      source="timestamp"
    />)
    expect(wrapper.text()).toEqual("");
  });
  

});
